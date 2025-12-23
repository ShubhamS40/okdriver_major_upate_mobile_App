const axios = require('axios');
const gTTS = require('gtts');
const fs = require('fs');
const path = require('path');

const SYSTEM_PROMPT = `
You are OkDriver - the coolest, most helpful driver assistant bot ever created! 🚗
PERSONALITY TRAITS:
- Call users "bro" in a friendly, supportive way
- Use casual, relatable language mixing Hindi-English (Hinglish)
- Be encouraging, motivational, and always positive
- Think like a best friend who's always there for support
- Use emojis naturally but don't overdo it
CORE CAPABILITIES:
🚗 DRIVING & NAVIGATION, 🔧 VEHICLE CARE, 🍔 FOOD & STOPS, 💰 MONEY MATTERS,
❤️ EMOTIONAL SUPPORT, 🎵 ENTERTAINMENT, ⚠️ SAFETY FIRST, 🆘 EMERGENCY
RESPONSE STYLE:
- Keep responses 25-50 words
- Conversational, not robotic
- Mix Hindi-English
- Prioritize safety
`;

const TOGETHER_API_KEY = 'tgp_v1_XBFDv9mEcbeFbYHqN-tnkFPFx-_7Vlths84jPqj3Y-c';
const TOGETHER_API_URL = 'https://api.together.xyz/chat/completions';

exports.generateOkDriverResponse = async (req, res) => {
  try {
    const userMessage = req.body?.message;
    if (!userMessage) {
      return res.status(400).json({ error: "Bro, message field is missing 😅" });
    }

    // 1️⃣ Generate AI Response
    const payload = {
      model: "meta-llama/Llama-3.3-70B-Instruct-Turbo-Free",
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userMessage }
      ],
      max_tokens: 150,
      temperature: 0.8
    };

    const aiResponse = await axios.post(TOGETHER_API_URL, payload, {
      headers: {
        "Authorization": `Bearer ${TOGETHER_API_KEY}`,
        "Content-Type": "application/json"
      }
    });

    const reply =
      aiResponse.data?.choices?.[0]?.message?.content?.trim() ||
      "Sorry bro, kuch samajh nahi aaya 😅";

    console.log("🧠 OkDriver Reply:", reply);

    // 2️⃣ Convert to Speech and Save File
    const outputDir = path.join(__dirname, "../uploads");
    if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir);

    const fileName = `reply_${Date.now()}.mp3`;
    const filePath = path.join(outputDir, fileName);
    const tts = new gTTS(reply, 'en');

    await new Promise((resolve, reject) => {
      tts.save(filePath, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });

    // 3️⃣ Return JSON with clickable audio URL
    const serverUrl = `${req.protocol}://${req.get('host')}`; // e.g., http://localhost:5000
    const audioUrl = `${serverUrl}/uploads/${fileName}`;

    res.status(200).json({
      reply,
      audioUrl
    });

  } catch (err) {
    console.error("❌ Error generating OkDriver response:", err.response?.data || err.message);
    res.status(500).json({ error: "Bro, kuch error ho gaya 😓" });
  }
};
