const path = require('path');
const fs = require('fs');
const axios = require('axios');
const Together = require('together-ai');

const conversationHistories = new Map();
const audioDir = path.join(__dirname, '../audio');

const together = new Together({ apiKey: process.env.TOGETHER_API_KEY });
const MAYA_API_URL = 'https://api.mayaresearch.ai';

function cleanAIResponse(response) {
  return response.replace(/<think>[\s\S]*?<\/think>/g, '').replace(/\n{2,}/g, '\n').trim();
}

async function generateSpeech(text, outputPath) {
  try {
    const requestBody = {
      text,
      speaker_id: "vinaya_assist",
      output_format: "wav",
      temperature: 0.5,
      streaming: false,
      normalize: true
    };

    const response = await axios.post(`${MAYA_API_URL}/generate`, requestBody, {
      headers: {
        'Authorization': `Bearer ${process.env.MAYA_API_KEY}`,
        'Content-Type': 'application/json'
      },
      responseType: 'arraybuffer'
    });

    fs.writeFileSync(outputPath, Buffer.from(response.data));
    return true;
  } catch (error) {
    console.error('Error generating speech:', error.response?.data || error.message);
    return false;
  }
}

exports.chat = async (req, res) => {
  try {
    const { message, conversation_history = [], userId = 'default' } = req.body;
    if (!message || message.trim() === '') return res.status(400).json({ error: 'Message is required' });

    let history = conversationHistories.get(userId) || [];
    history.push({ role: "user", content: message });
    if (history.length > 10) history = history.slice(-10);

    const messages = [{
      role: "system",
      content: "You are a helpful AI assistant. Respond naturally in English, Hindi, or Hinglish."
    }, ...history];

    const aiResponse = await together.chat.completions.create({
      messages,
      model: "deepseek-ai/DeepSeek-R1-Distill-Llama-70B-free",
      max_tokens: 1000,
      temperature: 0.7,
      stream: false
    });

    const aiMessage = aiResponse.choices[0]?.message?.content || "No response.";
    const cleanedResponse = cleanAIResponse(aiMessage);

    history.push({ role: "assistant", content: cleanedResponse });
    conversationHistories.set(userId, history);

    const audioFileName = `response_${Date.now()}_${Math.random().toString(36).substring(2)}.wav`;
    const audioPath = path.join(audioDir, audioFileName);
    const audioUrl = `${req.protocol}://${req.get('host')}/audio/${audioFileName}`;

    const speechGenerated = await generateSpeech(cleanedResponse, audioPath);

    res.json({
      response: cleanedResponse,
      audio_url: speechGenerated ? audioUrl : null,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Chat error:', error);
    const status = error.response?.status;
    if (status === 429) return res.status(429).json({ error: 'Rate limit exceeded.' });
    if (status === 401) return res.status(401).json({ error: 'Invalid API key.' });
    res.status(500).json({ error: 'Internal server error.', audio_url: null });
  }
};