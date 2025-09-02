const path = require('path');
const fs = require('fs');
const axios = require('axios');
const Together = require('together-ai');

// ====== Constants and Config ======
const MAYA_API_URL = 'https://api.mayaresearch.ai';
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || 'your-openai-api-key-here';
const AVAILABLE_SPEAKERS = {
  'varun_chat': 'Varun (Default)',
  'keerti_joy': 'Keerti Joy'
};

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

// ====== State Stores ======
const conversationHistories = new Map();
const pendingAudioJobs = new Map();
const userSettings = new Map();

// ====== Paths and Setup ======
const audioDir = path.join(__dirname, '../../audio');
if (!fs.existsSync(audioDir)) {
  fs.mkdirSync(audioDir, { recursive: true });
}

const together = new Together({ apiKey: process.env.TOGETHER_API_KEY });

// ====== Helpers ======
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

IMPORTANT: Always prioritize safety - if driver sounds tired/sleepy, immediately suggest they stop and rest.`;

  return language === 'english' ? basePrompt.replace(/Hindi-English \(Hinglish\)/g, 'English') : basePrompt;
}

function detectLanguage(text) {
  const hindiChars = (text.match(/[\u0900-\u097F]/g) || []).length;
  const englishWords = text.split(/\s+/).filter(word => /^[a-zA-Z]+$/.test(word)).length;
  const totalWords = text.split(/\s+/).length;
  const hinglishWords = ['hai', 'ka', 'ki', 'ko', 'main', 'mein', 'kya', 'kaise', 'kyun', 'bhai', 'yaar', 'acha', 'theek', 'ho', 'karo', 'kar', 'na', 'nahi', 'haan', 'tum', 'tumhara', 'mera', 'tera', 'bro'];
  const hasHinglishWords = hinglishWords.some(word => text.toLowerCase().includes(word));
  if (hindiChars > 0 || hasHinglishWords) return 'hinglish';
  if (englishWords / totalWords > 0.7) return 'english';
  return 'hinglish';
}

function cleanAIResponse(response) {
  let cleaned = (response || '')
    .replace(/<think>[\s\S]*?<\/think>/gi, '')
    .replace(/<thinking>[\s\S]*?<\/thinking>/gi, '')
    .replace(/\*\*thinking\*\*[\s\S]*?(?=\n\n|\n[A-Z]|$)/gi, '')
    .replace(/\n\s*Alright,[\s\S]*?(?=\n\n|\n[A-Z]|$)/gi, '')
    .replace(/\n\s*First,[\s\S]*?(?=\n\n|\n[A-Z]|$)/gi, '')
    .replace(/\n\s*I need to[\s\S]*?(?=\n\n|\n[A-Z]|$)/gi, '')
    .replace(/\n\s*Let me[\s\S]*?(?=\n\n|\n[A-Z]|$)/gi, '')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
  const words = cleaned.split(/\s+/).filter(w => w.length > 0);
  if (words.length > 100) {
    cleaned = words.slice(0, 100).join(' ');
    if (!/[.!?]$/.test(cleaned)) cleaned += '.';
  }
  if (!cleaned || cleaned.length < 3) cleaned = 'Yo bro! Main yahan hun tumhari help ke liye. Bolo kya chahiye?';
  return cleaned;
}

async function generateWithMayaAI(text, outputPath, speakerId) {
  try {
    if (!process.env.MAYA_API_KEY || process.env.MAYA_API_KEY === 'your-maya-api-key-here') {
      throw new Error('Maya AI API key not configured');
    }
    if (!speakerId) throw new Error('Speaker ID is required');
    let cleanText = (text || 'Yo bro! Main yahan hun tumhari help ke liye.')
      .replace(/<[^>]*>/g, '')
      .replace(/[^\w\s.,!?;:'-]/g, '')
      .trim();
    if (cleanText.length < 28) cleanText += ' Main hamesha tumhari help ke liye ready hun bro!';
    const requestBody = { text: cleanText, speaker_id: speakerId, output_format: 'wav', temperature: 0.4, streaming: false, normalize: true };
    const response = await axios.post(`${MAYA_API_URL}/generate`, requestBody, {
      headers: { 'Authorization': `Bearer ${process.env.MAYA_API_KEY}`, 'Content-Type': 'application/json' },
      responseType: 'arraybuffer', timeout: 30000
    });
    fs.writeFileSync(outputPath, Buffer.from(response.data));
    if (!AVAILABLE_SPEAKERS[speakerId]) AVAILABLE_SPEAKERS[speakerId] = `Speaker: ${speakerId}`;
    return true;
  } catch (error) {
    console.error('Maya AI TTS error:', { status: error.response?.status, statusText: error.response?.statusText, message: error.message, speakerId });
    return false;
  }
}

async function callOpenAI(messages, model = 'gpt-4o-mini') {
  const apiKey = OPENAI_API_KEY;
  if (!apiKey || apiKey === 'your-openai-api-key-here') throw new Error('OpenAI API key not configured');
  const response = await axios.post('https://api.openai.com/v1/chat/completions', {
    model, messages, max_tokens: 150, temperature: 0.8, stop: ['<think>', '<thinking>']
  }, { headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' }, timeout: 15000 });
  return response.data.choices[0]?.message?.content || 'Sorry bro, kuch technical issue hai.';
}

function validateModelAndProvider(modelProvider, modelName) {
  const providerModels = AVAILABLE_MODELS[modelProvider];
  if (!providerModels) return { valid: false, error: `Invalid model provider: ${modelProvider}. Available: ${Object.keys(AVAILABLE_MODELS).join(', ')}` };
  if (!providerModels[modelName]) return { valid: false, error: `Invalid model for ${modelProvider}: ${modelName}. Available: ${Object.keys(providerModels).join(', ')}` };
  return { valid: true };
}

async function generateSpeechAsync(text, outputPath, audioId, speakerId = 'varun_chat') {
  try {
    const success = await generateWithMayaAI(text, outputPath, speakerId);
    if (pendingAudioJobs.has(audioId)) {
      pendingAudioJobs.set(audioId, { status: success ? 'completed' : 'failed', path: success ? outputPath : null, error: success ? null : 'TTS generation failed' });
    }
    return success;
  } catch (error) {
    if (pendingAudioJobs.has(audioId)) pendingAudioJobs.set(audioId, { status: 'failed', error: error.message });
    return false;
  }
}

// ====== Controllers ======
exports.chat = async (req, res) => {
  try {
    const { message, userId = 'default', modelProvider, modelName, speakerId, enablePremium = false } = req.body;
    if (!message || message.trim() === '') return res.status(400).json({ error: 'Message is required' });
    if (!modelProvider) return res.status(400).json({ error: 'Model provider is required', available_providers: Object.keys(AVAILABLE_MODELS) });
    if (!modelName) return res.status(400).json({ error: 'Model name is required', available_models: AVAILABLE_MODELS });
    if (!speakerId) return res.status(400).json({ error: 'Speaker ID is required', message: 'Please provide speakerId in request body' });
    const validation = validateModelAndProvider(modelProvider, modelName);
    if (!validation.valid) return res.status(400).json({ error: validation.error, available_models: AVAILABLE_MODELS });
    const isPremiumModel = modelName.includes('gpt-4') || modelName.includes('70B');
    if (isPremiumModel && !enablePremium) return res.status(403).json({ error: 'Premium model access not enabled. Set enablePremium: true in request.', availableModels: AVAILABLE_MODELS });

    const userLanguage = detectLanguage(message);
    console.log(`[Assistant][CHAT] userId:${userId} provider:${modelProvider} model:${modelName} speaker:${speakerId}`);
    console.log(`[Assistant][CHAT] user -> ${message}`);
    let history = conversationHistories.get(userId) || [];
    history.push({ role: 'user', content: message });
    if (history.length > 6) history = history.slice(-6);

    const messages = [{ role: 'system', content: getDriverAssistantPrompt(userLanguage) }, ...history];

    let aiMessage;
    if (modelProvider === 'openai') {
      aiMessage = await callOpenAI(messages, modelName);
    } else {
      const aiResponse = await together.chat.completions.create({ messages, model: modelName, max_tokens: 150, temperature: 0.8, stream: false, stop: ['<think>', '<thinking>', 'Alright,', 'First,', 'Let me'] });
      aiMessage = aiResponse.choices[0]?.message?.content || 'Yo bro! Kuch technical issue hai, try again.';
    }

    const cleanedResponse = cleanAIResponse(aiMessage);
    console.log(`[Assistant][CHAT] assistant <- ${cleanedResponse}`);
    history.push({ role: 'assistant', content: cleanedResponse });
    conversationHistories.set(userId, history);

    const audioId = `response_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const audioFileName = `${audioId}.wav`;
    const audioPath = path.join(audioDir, audioFileName);
    pendingAudioJobs.set(audioId, { status: 'pending', path: audioPath });
    generateSpeechAsync(cleanedResponse, audioPath, audioId, speakerId);

    res.json({ response: cleanedResponse, audio_id: audioId, speech_status: 'generating', model_used: `${modelProvider}: ${modelName}`, speaker_used: speakerId, timestamp: new Date().toISOString() });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error', response: 'Bro, kuch technical problem hai. Thoda wait karke try again.', audio_id: null, details: process.env.NODE_ENV === 'development' ? error.message : undefined });
  }
};

exports.getAudioStatus = (req, res) => {
  const audioId = req.params.audioId;
  const job = pendingAudioJobs.get(audioId);
  if (!job) return res.status(404).json({ error: 'Audio job not found' });
  if (job.status === 'completed') {
    const audioFileName = `${audioId}.wav`;
    const audioUrl = `${req.protocol}://${req.get('host')}/audio/${audioFileName}`;
    return res.json({ status: 'completed', audio_url: audioUrl });
  }
  return res.json({ status: job.status, error: job.error || null });
};

exports.getConfig = (req, res) => {
  res.json({
    available_models: AVAILABLE_MODELS,
    available_speakers: AVAILABLE_SPEAKERS,
    default_settings: { modelProvider: null, modelName: null, speakerId: null, enablePremium: false }
  });
};

exports.saveSettings = (req, res) => {
  const userId = req.params.userId;
  const { modelProvider, modelName, speakerId, enablePremium } = req.body;
  if (modelProvider && modelName) {
    const validation = validateModelAndProvider(modelProvider, modelName);
    if (!validation.valid) return res.status(400).json({ error: validation.error });
  }
  userSettings.set(userId, { modelProvider: modelProvider || null, modelName: modelName || null, speakerId: speakerId || null, enablePremium: enablePremium || false });
  res.json({ message: 'Settings saved successfully' });
};

exports.getSettings = (req, res) => {
  const userId = req.params.userId;
  const settings = userSettings.get(userId) || { modelProvider: null, modelName: null, speakerId: null, enablePremium: false };
  res.json(settings);
};

exports.testSpeakers = async (req, res) => {
  try {
    const testText = 'Hello, this is a test message to check available speakers.';
    const testSpeakers = ['varun_chat', 'keerti_joy', 'priya', 'amit', 'ravi', 'default'];
    const results = [];
    for (const speakerId of testSpeakers) {
      try {
        const audioId = `speaker_test_${speakerId}_${Date.now()}`;
        const audioFileName = `${audioId}.wav`;
        const audioPath = path.join(audioDir, audioFileName);
        const requestBody = { text: testText, speaker_id: speakerId, output_format: 'wav' };
        const response = await axios.post(`${MAYA_API_URL}/generate`, requestBody, { headers: { 'Authorization': `Bearer ${process.env.MAYA_API_KEY}`, 'Content-Type': 'application/json' }, responseType: 'arraybuffer', timeout: 15000 });
        fs.writeFileSync(audioPath, Buffer.from(response.data));
        const audioUrl = `${req.protocol}://${req.get('host')}/audio/${audioFileName}`;
        results.push({ speaker_id: speakerId, status: 'success', audio_url: audioUrl });
      } catch (error) {
        results.push({ speaker_id: speakerId, status: 'failed', error: error.response?.status || error.message });
      }
    }
    res.json({ message: 'Speaker testing completed', results, working_speakers: results.filter(r => r.status === 'success').map(r => r.speaker_id) });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

exports.testSpeech = async (req, res) => {
  try {
    const { text = 'Yo bro! This is OkDriver testing Maya AI text to speech.', speakerId = 'varun_chat' } = req.body;
    const audioId = `test_${Date.now()}`;
    const audioFileName = `${audioId}.wav`;
    const audioPath = path.join(audioDir, audioFileName);
    const audioUrl = `${req.protocol}://${req.get('host')}/audio/${audioFileName}`;
    pendingAudioJobs.set(audioId, { status: 'pending', path: audioPath });
    const success = await generateSpeechAsync(text, audioPath, audioId, speakerId);
    res.json({ success, provider: 'maya_ai', speaker: `${speakerId}: ${AVAILABLE_SPEAKERS[speakerId]}`, audio_id: audioId, text, audio_url: success ? audioUrl : null });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

exports.testAI = async (req, res) => {
  try {
    const { message = 'Hey OkDriver, how are you?', modelProvider, modelName } = req.body;
    if (!modelProvider || !modelName) return res.status(400).json({ success: false, error: 'Both modelProvider and modelName are required', available_models: AVAILABLE_MODELS });
    const validation = validateModelAndProvider(modelProvider, modelName);
    if (!validation.valid) return res.status(400).json({ success: false, error: validation.error });
    const messages = [{ role: 'system', content: getDriverAssistantPrompt('hinglish') }, { role: 'user', content: message }];
    let aiMessage;
    if (modelProvider === 'openai') {
      aiMessage = await callOpenAI(messages, modelName);
    } else {
      const response = await together.chat.completions.create({ messages, model: modelName, max_tokens: 100, temperature: 0.8, stop: ['<think>', '<thinking>'] });
      aiMessage = response.choices[0]?.message?.content || 'No response generated';
    }
    const cleanedResponse = cleanAIResponse(aiMessage);
    res.json({ success: true, response: cleanedResponse, model_used: `${modelProvider}: ${modelName}`, original_message: message });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

exports.health = (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString(), services: { together_ai: process.env.TOGETHER_API_KEY ? 'Connected' : 'Not Configured', openai: process.env.OPENAI_API_KEY ? 'Connected' : 'Not Configured', maya_ai_tts: process.env.MAYA_API_KEY ? 'Connected' : 'Not Configured' } });
};

exports.getHistory = (req, res) => {
  const userId = 'default';
  const history = conversationHistories.get(userId) || [];
  res.json({ history });
};

exports.getUserHistory = (req, res) => {
  const userId = req.params.userId;
  const history = conversationHistories.get(userId) || [];
  res.json({ history });
};

exports.clearHistory = (req, res) => {
  const userId = 'default';
  conversationHistories.delete(userId);
  res.json({ message: 'History cleared successfully' });
};

exports.clearUserHistory = (req, res) => {
  const userId = req.params.userId;
  conversationHistories.delete(userId);
  res.json({ message: 'History cleared successfully' });
};