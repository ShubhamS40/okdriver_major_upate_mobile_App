const express = require('express');
const cors = require('cors');
const axios = require('axios');
const path = require('path');
const fs = require('fs');
const Together = require('together-ai');

const app = express();
const PORT = process.env.PORT || 3000;
const dotenv = require('dotenv'); 
dotenv.config(); // Load environment variables from .env file

// Initialize Together AI with your API key - MOVE TO ENVIRONMENT VARIABLES
const together = new Together({
  apiKey: process.env.TOGETHER_API_KEY || 'your-together-api-key-here'
});

// OpenAI Configuration - MOVE TO ENVIRONMENT VARIABLES
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || 'your-openai-api-key-here';

// Maya AI API configuration - MOVE TO ENVIRONMENT VARIABLES
const MAYA_API_URL = 'https://api.mayaresearch.ai';
const MAYA_API_KEY = process.env.MAYA_API_KEY || 'your-maya-api-key-here';

// Available TTS Speakers - This will be populated dynamically
const AVAILABLE_SPEAKERS = {
  // Speakers will be added dynamically when user provides them
  'varun_chat': 'Varun (Default)',
  'keerti_joy': 'Keerti Joy'
};

// Available AI Models - FIXED MODEL MAPPINGS
const AVAILABLE_MODELS = {
  together: {
    'meta-llama/Llama-3.2-3B-Instruct-Turbo': 'Llama 3.2 3B (Fast)',
    'meta-llama/Llama-3.2-11B-Vision-Instruct-Turbo': 'Llama 3.2 11B (Balanced)',
    'meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo': 'Llama 3.1 8B',
    'meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo': 'Llama 3.1 70B (Premium)',
    'mistralai/Mixtral-8x7B-Instruct-v0.1': 'Mixtral 8x7B',
    'NousResearch/Nous-Hermes-2-Mixtral-8x7B-DPO': 'Nous Hermes 2',
    'deepseek-ai/DeepSeek-R1-Distill-Llama-70B-free': 'DeepSeek R1 70B',
    'lgai/exaone-3-5-32b-instruct': 'ExaOne 3.5 32B',
    'arcee-ai/AFM-4.5B': 'Arcee AFM 4.5B'
  },
  openai: {
    'gpt-4o': 'GPT-4o (Premium)',
    'gpt-4o-mini': 'GPT-4o Mini',
    'gpt-4-turbo': 'GPT-4 Turbo (Premium)',
    'gpt-3.5-turbo': 'GPT-3.5 Turbo'
  }
};

// Storage
const conversationHistories = new Map();
const pendingAudioJobs = new Map();
const userSettings = new Map();

// Middleware
app.use(cors());
app.use(express.json());
app.use('/audio', express.static(path.join(__dirname, 'audio')));

// Create audio directory if it doesn't exist
const audioDir = path.join(__dirname, 'audio');
if (!fs.existsSync(audioDir)) {
  fs.mkdirSync(audioDir);
}

// Enhanced Driver Assistant System Prompt
function getDriverAssistantPrompt(language) {
  const basePrompt = `You are OkDriver - the coolest, most helpful driver assistant bot ever created! 🚗

PERSONALITY TRAITS:
- Call users "bro" in a friendly, supportive way
- Use casual, relatable language mixing Hindi-English (Hinglish)
- Be encouraging, motivational, and always positive
- Think like a best friend who's always there for support
- Use emojis naturally but don't overdo it

CORE CAPABILITIES:
🚗 DRIVING & NAVIGATION: Traffic updates, route suggestions, fuel stations, parking spots
🔧 VEHICLE CARE: Maintenance reminders, breakdown help, service centers
🍔 FOOD & STOPS: Recommend dhabas, restaurants, rest stops with ratings
💰 MONEY MATTERS: Cheapest fuel prices, cost-effective routes, budget tips
❤️ EMOTIONAL SUPPORT: Relationship advice, mood lifting, motivational talks
🎵 ENTERTAINMENT: Music suggestions, jokes, podcasts, games for long drives
⚠️ SAFETY FIRST: Always prioritize driver safety, suggest breaks when tired
🆘 EMERGENCY: Quick SOS alerts, accident help, emergency contacts

RESPONSE STYLE:
- Keep responses 25-50 words for quick readability while driving
- Be conversational, not robotic
- Use "bro" naturally but not in every sentence
- Mix Hindi-English words naturally
- Always be solution-oriented
- If you don't know something specific, admit it but offer alternatives

SAMPLE INTERACTIONS:
User: "Traffic kaisa hai aage?"
You: "Bro, aage thoda jam hai… chill maar, 10 mins delay. Alternative route suggest karu ya gaana chalu kar dun mood ke liye?"

User: "Feeling sad bro"
You: "Aree bro, sab theek ho jayega. Tu akela nahi hai - main hoon na! Ek deep breath le, koi motivational song bajau?"

User: "Petrol pump dhundh"
You: "Yo bro! 1.2 km pe HP pump hai, rates bhi decent chal rahe. Map share kar dun?"

IMPORTANT: Always prioritize safety - if driver sounds tired/sleepy, immediately suggest they stop and rest.`;

  return language === 'english' ? 
    basePrompt.replace(/Hindi-English \(Hinglish\)/g, 'English') :
    basePrompt;
}

// Helper function to detect language
function detectLanguage(text) {
  const hindiChars = (text.match(/[\u0900-\u097F]/g) || []).length;
  const englishWords = text.split(/\s+/).filter(word => /^[a-zA-Z]+$/.test(word)).length;
  const totalWords = text.split(/\s+/).length;
  
  const hinglishWords = ['hai', 'ka', 'ki', 'ko', 'main', 'mein', 'kya', 'kaise', 'kyun', 'bhai', 'yaar', 'acha', 'theek', 'ho', 'karo', 'kar', 'na', 'nahi', 'haan', 'tum', 'tumhara', 'mera', 'tera', 'bro'];
  const hasHinglishWords = hinglishWords.some(word => text.toLowerCase().includes(word));
  
  if (hindiChars > 0 || hasHinglishWords) {
    return 'hinglish';
  } else if (englishWords / totalWords > 0.7) {
    return 'english';
  } else {
    return 'hinglish';
  }
}

// Helper function to clean AI response
function cleanAIResponse(response) {
  let cleaned = response
    .replace(/<think>[\s\S]*?<\/think>/gi, '')
    .replace(/<thinking>[\s\S]*?<\/thinking>/gi, '')
    .replace(/\*\*thinking\*\*[\s\S]*?(?=\n\n|\n[A-Z]|$)/gi, '')
    .replace(/\n\s*Alright,[\s\S]*?(?=\n\n|\n[A-Z]|$)/gi, '')
    .replace(/\n\s*First,[\s\S]*?(?=\n\n|\n[A-Z]|$)/gi, '')
    .replace(/\n\s*I need to[\s\S]*?(?=\n\n|\n[A-Z]|$)/gi, '')
    .replace(/\n\s*Let me[\s\S]*?(?=\n\n|\n[A-Z]|$)/gi, '')
    .replace(/\n{3,}/g, '\n\n')
    .trim();

  // Count words and enforce 100 word limit
  const words = cleaned.split(/\s+/).filter(word => word.length > 0);
  
  if (words.length > 100) {
    cleaned = words.slice(0, 100).join(' ');
    if (!/[.!?]$/.test(cleaned)) {
      cleaned += '.';
    }
  }
  
  if (!cleaned || cleaned.length < 3) {
    cleaned = "Yo bro! Main yahan hun tumhari help ke liye. Bolo kya chahiye?";
  }
  
  return cleaned;
}

// Enhanced Maya AI TTS with flexible speaker ID
async function generateWithMayaAI(text, outputPath, speakerId) {
  try {
    if (!MAYA_API_KEY || MAYA_API_KEY === 'your-maya-api-key-here') {
      throw new Error('Maya AI API key not configured');
    }

    if (!speakerId) {
      throw new Error('Speaker ID is required');
    }

    if (!text || text.trim().length < 3) {
      text = "Yo bro! Main yahan hun tumhari help ke liye.";
    }

    let cleanText = text
      .replace(/<[^>]*>/g, '')
      .replace(/[^\w\s.,!?;:'-]/g, '')
      .trim();

    if (cleanText.length < 28) {
      cleanText = cleanText + " Main hamesha tumhari help ke liye ready hun bro!";
    }

    const requestBody = {
      text: cleanText,
      speaker_id: speakerId,
      output_format: "wav",
      temperature: 0.5,
      streaming: false,
      normalize: true
    };

    console.log(`Generating TTS with speaker: ${speakerId}, text length: ${cleanText.length}`);

    const response = await axios.post(
      `${MAYA_API_URL}/generate`,
      requestBody,
      {
        headers: {
          'Authorization': `Bearer ${MAYA_API_KEY}`,
          'Content-Type': 'application/json'
        },
        responseType: 'arraybuffer',
        timeout: 30000
      }
    );

    fs.writeFileSync(outputPath, Buffer.from(response.data));
    console.log(`Maya AI TTS: Audio file saved successfully with speaker: ${speakerId}`);
    
    // Add successful speaker to available speakers list
    if (!AVAILABLE_SPEAKERS[speakerId]) {
      AVAILABLE_SPEAKERS[speakerId] = `Speaker: ${speakerId}`;
      console.log(`Added new speaker to available list: ${speakerId}`);
    }
    
    return true;
  } catch (error) {
    console.error('Maya AI TTS error:', {
      status: error.response?.status,
      statusText: error.response?.statusText,
      message: error.message,
      speakerId: speakerId,
      textLength: text?.length
    });

    if (error.response?.status === 422) {
      console.log(`422 Error with speaker: ${speakerId} - Invalid speaker_id or parameters`);
    }

    return false;
  }
}

// OpenAI API call function
async function callOpenAI(messages, model = 'gpt-4o-mini') {
  try {
    if (!OPENAI_API_KEY || OPENAI_API_KEY === 'your-openai-api-key-here') {
      throw new Error('OpenAI API key not configured');
    }

    const response = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: model,
        messages: messages,
        max_tokens: 150,
        temperature: 0.8,
        stop: ["<think>", "<thinking>"]
      },
      {
        headers: {
          'Authorization': `Bearer ${OPENAI_API_KEY}`,
          'Content-Type': 'application/json'
        },
        timeout: 15000
      }
    );

    return response.data.choices[0]?.message?.content || "Sorry bro, kuch technical issue hai.";
  } catch (error) {
    console.error('OpenAI API error:', error.message);
    throw error;
  }
}

// FIXED: Model validation function
function validateModelAndProvider(modelProvider, modelName) {
  const providerModels = AVAILABLE_MODELS[modelProvider];
  if (!providerModels) {
    return {
      valid: false,
      error: `Invalid model provider: ${modelProvider}. Available: ${Object.keys(AVAILABLE_MODELS).join(', ')}`
    };
  }

  if (!providerModels[modelName]) {
    return {
      valid: false,
      error: `Invalid model for ${modelProvider}: ${modelName}. Available: ${Object.keys(providerModels).join(', ')}`
    };
  }

  return { valid: true };
}

// Enhanced chat endpoint with fixed model validation
app.post('/api/chat', async (req, res) => {
  try {
    const { 
      message, 
      userId = 'default',
      modelProvider, // Required - no default value
      modelName, // Required - no default value
      speakerId, // Required - no default value
      enablePremium = false
    } = req.body;

    if (!message || message.trim() === '') {
      return res.status(400).json({ error: 'Message is required' });
    }

    if (!modelProvider) {
      return res.status(400).json({ 
        error: 'Model provider is required',
        available_providers: Object.keys(AVAILABLE_MODELS)
      });
    }

    if (!modelName) {
      return res.status(400).json({ 
        error: 'Model name is required',
        available_models: AVAILABLE_MODELS
      });
    }

    if (!speakerId) {
      return res.status(400).json({ 
        error: 'Speaker ID is required',
        message: 'Please provide speakerId in request body'
      });
    }

    // FIXED: Validate model and provider combination
    const modelValidation = validateModelAndProvider(modelProvider, modelName);
    if (!modelValidation.valid) {
      return res.status(400).json({ 
        error: modelValidation.error,
        available_models: AVAILABLE_MODELS
      });
    }

    // Check if premium model is requested but not enabled
    const isPremiumModel = modelName.includes('gpt-4') || modelName.includes('70B');
    if (isPremiumModel && !enablePremium) {
      return res.status(403).json({ 
        error: 'Premium model access not enabled. Set enablePremium: true in request.',
        availableModels: AVAILABLE_MODELS
      });
    }

    const userLanguage = detectLanguage(message);
    
    // Get or create conversation history
    let history = conversationHistories.get(userId) || [];
    history.push({ role: "user", content: message });

    // Keep only last 6 messages for better context
    if (history.length > 6) {
      history = history.slice(-6);
    }

    const messages = [
      {
        role: "system",
        content: getDriverAssistantPrompt(userLanguage)
      },
      ...history
    ];

    let aiMessage;

    // Choose AI provider based on request
    if (modelProvider === 'openai') {
      aiMessage = await callOpenAI(messages, modelName);
    } else {
      // Use Together AI
      const aiResponse = await together.chat.completions.create({
        messages: messages,
        model: modelName,
        max_tokens: 150,
        temperature: 0.8,
        stream: false,
        stop: ["<think>", "<thinking>", "Alright,", "First,", "Let me"]
      });
      aiMessage = aiResponse.choices[0]?.message?.content || "Yo bro! Kuch technical issue hai, try again.";
    }

    const cleanedResponse = cleanAIResponse(aiMessage);

    // Add AI response to history
    history.push({ role: "assistant", content: cleanedResponse });
    conversationHistories.set(userId, history);

    // Generate audio with user-provided speaker
    const audioId = `response_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const audioFileName = `${audioId}.wav`;
    const audioPath = path.join(audioDir, audioFileName);

    // Start audio generation asynchronously
    pendingAudioJobs.set(audioId, { status: 'pending', path: audioPath });
    generateSpeechAsync(cleanedResponse, audioPath, audioId, speakerId);

    const responseData = {
      response: cleanedResponse,
      audio_id: audioId,
      speech_status: 'generating',
      model_used: `${modelProvider}: ${modelName}`,
      speaker_used: speakerId,
      timestamp: new Date().toISOString()
    };

    res.json(responseData);

  } catch (error) {
    console.error('Error in chat endpoint:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      response: "Bro, kuch technical problem hai. Thoda wait karke try again.",
      audio_id: null,
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Helper function for async speech generation
async function generateSpeechAsync(text, outputPath, audioId, speakerId = 'varun_chat') {
  try {
    const success = await generateWithMayaAI(text, outputPath, speakerId);
    
    if (pendingAudioJobs.has(audioId)) {
      pendingAudioJobs.set(audioId, { 
        status: success ? 'completed' : 'failed', 
        path: success ? outputPath : null,
        error: success ? null : 'TTS generation failed'
      });
    }
    
    return success;
  } catch (error) {
    console.error('Error in generateSpeechAsync:', error.message);
    
    if (pendingAudioJobs.has(audioId)) {
      pendingAudioJobs.set(audioId, { 
        status: 'failed', 
        error: error.message 
      });
    }
    
    return false;
  }
}

// Audio status endpoint
app.get('/api/audio-status/:audioId', (req, res) => {
  const audioId = req.params.audioId;
  const job = pendingAudioJobs.get(audioId);
  
  if (!job) {
    return res.status(404).json({ error: 'Audio job not found' });
  }
  
  if (job.status === 'completed') {
    const audioFileName = `${audioId}.wav`;
    const audioUrl = `${req.protocol}://${req.get('host')}/audio/${audioFileName}`;
    
    res.json({
      status: 'completed',
      audio_url: audioUrl
    });
  } else {
    res.json({
      status: job.status,
      error: job.error || null
    });
  }
});

// Get available models and speakers
app.get('/api/config', (req, res) => {
  res.json({
    available_models: AVAILABLE_MODELS,
    available_speakers: AVAILABLE_SPEAKERS,
    default_settings: {
      modelProvider: null, // User must provide
      modelName: null, // User must provide
      speakerId: null, // User must provide
      enablePremium: false
    }
  });
});

// User settings endpoints
app.post('/api/settings/:userId', (req, res) => {
  const userId = req.params.userId;
  const { modelProvider, modelName, speakerId, enablePremium } = req.body;
  
  // Validate model and provider
  if (modelProvider && modelName) {
    const validation = validateModelAndProvider(modelProvider, modelName);
    if (!validation.valid) {
      return res.status(400).json({ error: validation.error });
    }
  }
  
  userSettings.set(userId, {
    modelProvider: modelProvider || null, // No defaults
    modelName: modelName || null, // No defaults
    speakerId: speakerId || null, // No defaults
    enablePremium: enablePremium || false
  });
  
  res.json({ message: 'Settings saved successfully' });
});

app.get('/api/settings/:userId', (req, res) => {
  const userId = req.params.userId;
  const settings = userSettings.get(userId) || {
    modelProvider: null, // User must provide
    modelName: null, // User must provide
    speakerId: null, // User must provide
    enablePremium: false
  };
  
  res.json(settings);
});

// Test endpoints remain the same
app.post('/api/test-speakers', async (req, res) => {
  try {
    const testText = "Hello, this is a test message to check available speakers.";
    const testSpeakers = ['varun_chat', 'keerti_joy', 'priya', 'amit', 'ravi', 'default'];
    const results = [];

    for (const speakerId of testSpeakers) {
      try {
        const audioId = `speaker_test_${speakerId}_${Date.now()}`;
        const audioFileName = `${audioId}.wav`;
        const audioPath = path.join(audioDir, audioFileName);

        const requestBody = {
          text: testText,
          speaker_id: speakerId,
          output_format: "wav"
        };

        console.log(`Testing speaker: ${speakerId}`);

        const response = await axios.post(
          `${MAYA_API_URL}/generate`,
          requestBody,
          {
            headers: {
              'Authorization': `Bearer ${MAYA_API_KEY}`,
              'Content-Type': 'application/json'
            },
            responseType: 'arraybuffer',
            timeout: 15000
          }
        );

        fs.writeFileSync(audioPath, Buffer.from(response.data));
        const audioUrl = `${req.protocol}://${req.get('host')}/audio/${audioFileName}`;
        
        results.push({
          speaker_id: speakerId,
          status: 'success',
          audio_url: audioUrl
        });

        console.log(`✓ Speaker ${speakerId} works!`);
      } catch (error) {
        results.push({
          speaker_id: speakerId,
          status: 'failed',
          error: error.response?.status || error.message
        });
        console.log(`✗ Speaker ${speakerId} failed: ${error.response?.status}`);
      }
    }

    res.json({
      message: 'Speaker testing completed',
      results: results,
      working_speakers: results.filter(r => r.status === 'success').map(r => r.speaker_id)
    });

  } catch (error) {
    console.error('Error in test-speakers endpoint:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

app.post('/api/test-speech', async (req, res) => {
  try {
    const { 
      text = "Yo bro! This is OkDriver testing Maya AI text to speech.", 
      speakerId = 'varun_chat' 
    } = req.body;
    
    const audioId = `test_${Date.now()}`;
    const audioFileName = `${audioId}.wav`;
    const audioPath = path.join(audioDir, audioFileName);
    const audioUrl = `${req.protocol}://${req.get('host')}/audio/${audioFileName}`;

    pendingAudioJobs.set(audioId, { status: 'pending', path: audioPath });
    
    const success = await generateSpeechAsync(text, audioPath, audioId, speakerId);

    res.json({ 
      success: success, 
      provider: 'maya_ai',
      speaker: `${speakerId}: ${AVAILABLE_SPEAKERS[speakerId]}`,
      audio_id: audioId,
      text: text,
      audio_url: success ? audioUrl : null
    });
  } catch (error) {
    console.error('Error in test-speech endpoint:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

app.post('/api/test-ai', async (req, res) => {
  try {
    const { 
      message = "Hey OkDriver, how are you?",
      modelProvider, // Required - no default
      modelName // Required - no default
    } = req.body;

    if (!modelProvider || !modelName) {
      return res.status(400).json({ 
        success: false, 
        error: 'Both modelProvider and modelName are required',
        available_models: AVAILABLE_MODELS
      });
    }

    // Validate model and provider
    const validation = validateModelAndProvider(modelProvider, modelName);
    if (!validation.valid) {
      return res.status(400).json({ success: false, error: validation.error });
    }

    const messages = [
      {
        role: "system",
        content: getDriverAssistantPrompt('hinglish')
      },
      {
        role: "user",
        content: message
      }
    ];

    let aiMessage;

    if (modelProvider === 'openai') {
      aiMessage = await callOpenAI(messages, modelName);
    } else {
      const response = await together.chat.completions.create({
        messages: messages,
        model: modelName,
        max_tokens: 100,
        temperature: 0.8,
        stop: ["<think>", "<thinking>"]
      });
      aiMessage = response.choices[0]?.message?.content || "No response generated";
    }

    const cleanedResponse = cleanAIResponse(aiMessage);

    res.json({ 
      success: true, 
      response: cleanedResponse,
      model_used: `${modelProvider}: ${modelName}`,
      original_message: message
    });
  } catch (error) {
    console.error('Error in test-ai endpoint:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    services: {
      together_ai: process.env.TOGETHER_API_KEY ? 'Connected' : 'Not Configured',
      openai: process.env.OPENAI_API_KEY ? 'Connected' : 'Not Configured',
      maya_ai_tts: process.env.MAYA_API_KEY ? 'Connected' : 'Not Configured'
    }
  });
});

// History endpoints
app.get('/api/history', (req, res) => {
  const userId = 'default';
  const history = conversationHistories.get(userId) || [];
  res.json({ history });
});

app.get('/api/history/:userId', (req, res) => {
  const userId = req.params.userId;
  const history = conversationHistories.get(userId) || [];
  res.json({ history });
});

app.delete('/api/history', (req, res) => {
  const userId = 'default';
  conversationHistories.delete(userId);
  res.json({ message: 'History cleared successfully' });
});

app.delete('/api/history/:userId', (req, res) => {
  const userId = req.params.userId;
  conversationHistories.delete(userId);
  res.json({ message: 'History cleared successfully' });
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({ 
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? error.message : 'Something went wrong'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Cleanup old files (run every 30 minutes)
setInterval(() => {
  const now = Date.now();
  const thirtyMinutes = 30 * 60 * 1000;

  fs.readdir(audioDir, (err, files) => {
    if (err) return;

    files.forEach(file => {
      const filePath = path.join(audioDir, file);
      fs.stat(filePath, (err, stats) => {
        if (err) return;

        if (now - stats.mtime.getTime() > thirtyMinutes) {
          fs.unlink(filePath, (err) => {
            if (!err) {
              console.log(`Deleted old audio file: ${file}`);
            }
          });
        }
      });
    });
  });

  for (const [audioId, job] of pendingAudioJobs.entries()) {
    if (now - parseInt(audioId.split('_')[1]) > thirtyMinutes) {
      pendingAudioJobs.delete(audioId);
    }
  }
}, 30 * 60 * 1000);

app.listen(3000, () => {
  console.log(`🚗 OkDriver Assistant API running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/api/health`);
  console.log(`💬 Chat endpoint: POST http://localhost:${PORT}/api/chat`);
  console.log(`⚙️  Configuration: GET http://localhost:${PORT}/api/config`);
  console.log(`🎤 Test TTS: POST http://localhost:${PORT}/api/test-speech`);
  console.log(`🤖 Test AI: POST http://localhost:${PORT}/api/test-ai`);
  console.log(`📡 Audio status: GET http://localhost:${PORT}/api/audio-status/:audioId`);
  console.log(`📋 History: GET/DELETE http://localhost:${PORT}/api/history/:userId`);
  console.log(`⚙️  Settings: GET/POST http://localhost:${PORT}/api/settings/:userId`);
  console.log(`\n⚠️  SECURITY WARNING: Move API keys to environment variables!`);
});