

import io
import os
import re
import json
import wave
import torch
import asyncio
import tempfile
import numpy as np
from TTS.api import TTS
from together import Together
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
import speech_recognition as sr
import base64

# ─────────────────────────────────────────
# SETUP
# ─────────────────────────────────────────
app = FastAPI(title="OkDriver Voice Assistant")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

TOGETHER_API_KEY = "tgp_v1_hCuJKHjarpIlQ6wqW2LjubGyjdTIOBEmNQMVEnq-n4k"

# Load XTTS v2 once at startup
print("🔄 Loading XTTS v2 model...")
device = "cuda" if torch.cuda.is_available() else "cpu"
tts_model = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to(device)
print(f"✅ XTTS v2 loaded on {device}")

together_client = Together(api_key=TOGETHER_API_KEY)

SYSTEM_PROMPT = """You are OkDriver's friendly female voice assistant.
- Reply in the same language the user speaks (Hindi, English, or Hinglish)
- Keep replies SHORT and conversational — like a real human friend
- Use natural fillers: 'Hmm', 'Achha', 'Bilkul', 'Dekho', 'Actually'
- Never sound robotic or formal
- Max 3-4 sentences per reply"""

# ─────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────

def split_into_sentences(text: str) -> list[str]:
    """Split text into small chunks for faster streaming TTS"""
    # Split on sentence endings and natural pauses
    chunks = re.split(r'(?<=[।.!?,;])\s+', text.strip())
    result = []
    for chunk in chunks:
        chunk = chunk.strip()
        if len(chunk) > 5:
            result.append(chunk)
    return result if result else [text]


def generate_tts_chunk(text: str) -> bytes:
    """Generate WAV bytes for a single text chunk using XTTS v2"""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp_path = tmp.name

    tts_model.tts_to_file(
        text=text,
        file_path=tmp_path,
        speaker="Ana Florence",
        language="hi",
    )

    with open(tmp_path, "rb") as f:
        wav_bytes = f.read()

    os.unlink(tmp_path)
    return wav_bytes


def transcribe_audio(audio_bytes: bytes) -> str:
    """Convert audio bytes to text - handles WebM/WAV both"""
    recognizer = sr.Recognizer()
    
    with tempfile.NamedTemporaryFile(suffix=".webm", delete=False) as tmp:
        tmp.write(audio_bytes)
        webm_path = tmp.name

    wav_path = webm_path.replace(".webm", ".wav")

    try:
        # WebM → WAV convert karo ffmpeg se
        os.system(f"ffmpeg -i {webm_path} -ar 16000 -ac 1 {wav_path} -y -loglevel quiet")

        with sr.AudioFile(wav_path) as source:
            audio = recognizer.record(source)
        text = recognizer.recognize_google(audio, language="hi-IN")
        print(f"✅ STT: {text}")
        return text
    except Exception as e:
        print(f"STT error: {e}")
        return ""
    finally:
        if os.path.exists(webm_path): os.unlink(webm_path)
        if os.path.exists(wav_path): os.unlink(wav_path)

# ─────────────────────────────────────────
# WEBSOCKET ENDPOINT
# ─────────────────────────────────────────

@app.websocket("/ws/talk")
async def websocket_talk(websocket: WebSocket):
    await websocket.accept()
    print("🔌 Client connected")

    conversation_history = []

    try:
        while True:
            # ── Receive audio bytes from browser ──
            data = await websocket.receive_bytes()
            await websocket.send_text(json.dumps({"type": "status", "msg": "Samajh rahi hoon..."}))

            # ── STT ──
            loop = asyncio.get_event_loop()
            user_text = await loop.run_in_executor(None, transcribe_audio, data)

            if not user_text.strip():
                await websocket.send_text(json.dumps({"type": "error", "msg": "Kuch samajh nahi aaya, dobara bolein"}))
                continue

            print(f"👤 User: {user_text}")
            await websocket.send_text(json.dumps({"type": "transcript", "text": user_text}))
            await websocket.send_text(json.dumps({"type": "status", "msg": "Soch rahi hoon..."}))

            # ── Together AI - Streaming ──
            conversation_history.append({"role": "user", "content": user_text})

            full_reply = ""
            buffer = ""

            stream = together_client.chat.completions.create(
                model="meta-llama/Llama-3.3-70B-Instruct-Turbo-Free",
                messages=[{"role": "system", "content": SYSTEM_PROMPT}] + conversation_history,
                stream=True,
                max_tokens=200,
            )

            await websocket.send_text(json.dumps({"type": "status", "msg": "Bol rahi hoon..."}))

            # ── Stream text + generate TTS chunk by chunk ──
            for token in stream:
                chunk_text = token.choices[0].delta.content or ""
                full_reply += chunk_text
                buffer += chunk_text

                # Send text token to frontend immediately
                await websocket.send_text(json.dumps({"type": "text_chunk", "text": chunk_text}))

                # When buffer has a full sentence, generate TTS
                if any(p in buffer for p in ["।", ".", "!", "?", ",", ";"]):
                    sentences = split_into_sentences(buffer)

                    for sentence in sentences[:-1]:  # All complete sentences
                        if len(sentence.strip()) > 3:
                            print(f"🔊 TTS chunk: {sentence}")
                            wav_bytes = await loop.run_in_executor(
                                None, generate_tts_chunk, sentence
                            )
                            # Send audio chunk as base64
                            audio_b64 = base64.b64encode(wav_bytes).decode()
                            await websocket.send_text(json.dumps({
                                "type": "audio_chunk",
                                "audio": audio_b64
                            }))

                    # Keep incomplete last part in buffer
                    buffer = sentences[-1] if sentences else ""

            # ── Flush remaining buffer ──
            if buffer.strip() and len(buffer.strip()) > 3:
                wav_bytes = await loop.run_in_executor(None, generate_tts_chunk, buffer.strip())
                audio_b64 = base64.b64encode(wav_bytes).decode()
                await websocket.send_text(json.dumps({
                    "type": "audio_chunk",
                    "audio": audio_b64
                }))

            # ── Done ──
            conversation_history.append({"role": "assistant", "content": full_reply})
            print(f"🤖 Assistant: {full_reply}")
            await websocket.send_text(json.dumps({"type": "done", "full_text": full_reply}))

    except WebSocketDisconnect:
        print("🔌 Client disconnected")
    except Exception as e:
        print(f"❌ Error: {e}")
        await websocket.send_text(json.dumps({"type": "error", "msg": str(e)}))


# ─────────────────────────────────────────
# SERVE FRONTEND
# ─────────────────────────────────────────

@app.get("/")
async def get():
    with open("index.html", "r") as f:
        return HTMLResponse(f.read())


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)"""
OkDriver Voice Assistant - Backend
Together AI (LLM) + XTTS v2 (TTS) + WebSocket Streaming
"""

import io
import os
import re
import json
import wave
import torch
import asyncio
import tempfile
import numpy as np
from TTS.api import TTS
from together import Together
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
import speech_recognition as sr
import base64

# ─────────────────────────────────────────
# SETUP
# ─────────────────────────────────────────
app = FastAPI(title="OkDriver Voice Assistant")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

TOGETHER_API_KEY = "tgp_v1_hCuJKHjarpIlQ6wqW2LjubGyjdTIOBEmNQMVEnq-n4k"

# Load XTTS v2 once at startup
print("🔄 Loading XTTS v2 model...")
device = "cuda" if torch.cuda.is_available() else "cpu"
tts_model = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to(device)
print(f"✅ XTTS v2 loaded on {device}")

together_client = Together(api_key=TOGETHER_API_KEY)

SYSTEM_PROMPT = """You are OkDriver's friendly female voice assistant.
- Reply in the same language the user speaks (Hindi, English, or Hinglish)
- Keep replies SHORT and conversational — like a real human friend
- Use natural fillers: 'Hmm', 'Achha', 'Bilkul', 'Dekho', 'Actually'
- Never sound robotic or formal
- Max 3-4 sentences per reply"""

# ─────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────

def split_into_sentences(text: str) -> list[str]:
    """Split text into small chunks for faster streaming TTS"""
    # Split on sentence endings and natural pauses
    chunks = re.split(r'(?<=[।.!?,;])\s+', text.strip())
    result = []
    for chunk in chunks:
        chunk = chunk.strip()
        if len(chunk) > 5:
            result.append(chunk)
    return result if result else [text]


def generate_tts_chunk(text: str) -> bytes:
    """Generate WAV bytes for a single text chunk using XTTS v2"""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp_path = tmp.name

    tts_model.tts_to_file(
        text=text,
        file_path=tmp_path,
        speaker="Ana Florence",
        language="hi",
    )

    with open(tmp_path, "rb") as f:
        wav_bytes = f.read()

    os.unlink(tmp_path)
    return wav_bytes


def transcribe_audio(audio_bytes: bytes) -> str:
    """Convert audio bytes to text using Google STT"""
    recognizer = sr.Recognizer()
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp.write(audio_bytes)
        tmp_path = tmp.name

    try:
        with sr.AudioFile(tmp_path) as source:
            audio = recognizer.record(source)
        text = recognizer.recognize_google(audio, language="hi-IN")
        return text
    except Exception as e:
        print(f"STT error: {e}")
        return ""
    finally:
        os.unlink(tmp_path)


# ─────────────────────────────────────────
# WEBSOCKET ENDPOINT
# ─────────────────────────────────────────

@app.websocket("/ws/talk")
async def websocket_talk(websocket: WebSocket):
    await websocket.accept()
    print("🔌 Client connected")

    conversation_history = []

    try:
        while True:
            # ── Receive audio bytes from browser ──
            data = await websocket.receive_bytes()
            await websocket.send_text(json.dumps({"type": "status", "msg": "Samajh rahi hoon..."}))

            # ── STT ──
            loop = asyncio.get_event_loop()
            user_text = await loop.run_in_executor(None, transcribe_audio, data)

            if not user_text.strip():
                await websocket.send_text(json.dumps({"type": "error", "msg": "Kuch samajh nahi aaya, dobara bolein"}))
                continue

            print(f"👤 User: {user_text}")
            await websocket.send_text(json.dumps({"type": "transcript", "text": user_text}))
            await websocket.send_text(json.dumps({"type": "status", "msg": "Soch rahi hoon..."}))

            # ── Together AI - Streaming ──
            conversation_history.append({"role": "user", "content": user_text})

            full_reply = ""
            buffer = ""

            stream = together_client.chat.completions.create(
                model="meta-llama/Llama-3.3-70B-Instruct-Turbo-Free",
                messages=[{"role": "system", "content": SYSTEM_PROMPT}] + conversation_history,
                stream=True,
                max_tokens=200,
            )

            await websocket.send_text(json.dumps({"type": "status", "msg": "Bol rahi hoon..."}))

            # ── Stream text + generate TTS chunk by chunk ──
            for token in stream:
                chunk_text = token.choices[0].delta.content or ""
                full_reply += chunk_text
                buffer += chunk_text

                # Send text token to frontend immediately
                await websocket.send_text(json.dumps({"type": "text_chunk", "text": chunk_text}))

                # When buffer has a full sentence, generate TTS
                if any(p in buffer for p in ["।", ".", "!", "?", ",", ";"]):
                    sentences = split_into_sentences(buffer)

                    for sentence in sentences[:-1]:  # All complete sentences
                        if len(sentence.strip()) > 3:
                            print(f"🔊 TTS chunk: {sentence}")
                            wav_bytes = await loop.run_in_executor(
                                None, generate_tts_chunk, sentence
                            )
                            # Send audio chunk as base64
                            audio_b64 = base64.b64encode(wav_bytes).decode()
                            await websocket.send_text(json.dumps({
                                "type": "audio_chunk",
                                "audio": audio_b64
                            }))

                    # Keep incomplete last part in buffer
                    buffer = sentences[-1] if sentences else ""

            # ── Flush remaining buffer ──
            if buffer.strip() and len(buffer.strip()) > 3:
                wav_bytes = await loop.run_in_executor(None, generate_tts_chunk, buffer.strip())
                audio_b64 = base64.b64encode(wav_bytes).decode()
                await websocket.send_text(json.dumps({
                    "type": "audio_chunk",
                    "audio": audio_b64
                }))

            # ── Done ──
            conversation_history.append({"role": "assistant", "content": full_reply})
            print(f"🤖 Assistant: {full_reply}")
            await websocket.send_text(json.dumps({"type": "done", "full_text": full_reply}))

    except WebSocketDisconnect:
        print("🔌 Client disconnected")
    except Exception as e:
        print(f"❌ Error: {e}")
        await websocket.send_text(json.dumps({"type": "error", "msg": str(e)}))


# ─────────────────────────────────────────
# SERVE FRONTEND
# ─────────────────────────────────────────

@app.get("/")
async def get():
    with open("index.html", "r") as f:
        return HTMLResponse(f.read())


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)"""
OkDriver Voice Assistant - Backend
Together AI (LLM) + XTTS v2 (TTS) + WebSocket Streaming
"""

import io
import os
import re
import json
import wave
import torch
import asyncio
import tempfile
import numpy as np
from TTS.api import TTS
from together import Together
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
import speech_recognition as sr
import base64

# ─────────────────────────────────────────
# SETUP
# ─────────────────────────────────────────
app = FastAPI(title="OkDriver Voice Assistant")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

TOGETHER_API_KEY = "tgp_v1_hCuJKHjarpIlQ6wqW2LjubGyjdTIOBEmNQMVEnq-n4k"

# Load XTTS v2 once at startup
print("🔄 Loading XTTS v2 model...")
device = "cuda" if torch.cuda.is_available() else "cpu"
tts_model = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to(device)
print(f"✅ XTTS v2 loaded on {device}")

together_client = Together(api_key=TOGETHER_API_KEY)

SYSTEM_PROMPT = """You are OkDriver's friendly female voice assistant.
- Reply in the same language the user speaks (Hindi, English, or Hinglish)
- Keep replies SHORT and conversational — like a real human friend
- Use natural fillers: 'Hmm', 'Achha', 'Bilkul', 'Dekho', 'Actually'
- Never sound robotic or formal
- Max 3-4 sentences per reply"""

# ─────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────

def split_into_sentences(text: str) -> list[str]:
    """Split text into small chunks for faster streaming TTS"""
    # Split on sentence endings and natural pauses
    chunks = re.split(r'(?<=[।.!?,;])\s+', text.strip())
    result = []
    for chunk in chunks:
        chunk = chunk.strip()
        if len(chunk) > 5:
            result.append(chunk)
    return result if result else [text]


def generate_tts_chunk(text: str) -> bytes:
    """Generate WAV bytes for a single text chunk using XTTS v2"""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp_path = tmp.name

    tts_model.tts_to_file(
        text=text,
        file_path=tmp_path,
        speaker="Ana Florence",
        language="hi",
    )

    with open(tmp_path, "rb") as f:
        wav_bytes = f.read()

    os.unlink(tmp_path)
    return wav_bytes


def transcribe_audio(audio_bytes: bytes) -> str:
    """Convert audio bytes to text using Google STT"""
    recognizer = sr.Recognizer()
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp.write(audio_bytes)
        tmp_path = tmp.name

    try:
        with sr.AudioFile(tmp_path) as source:
            audio = recognizer.record(source)
        text = recognizer.recognize_google(audio, language="hi-IN")
        return text
    except Exception as e:
        print(f"STT error: {e}")
        return ""
    finally:
        os.unlink(tmp_path)


# ─────────────────────────────────────────
# WEBSOCKET ENDPOINT
# ─────────────────────────────────────────

@app.websocket("/ws/talk")
async def websocket_talk(websocket: WebSocket):
    await websocket.accept()
    print("🔌 Client connected")

    conversation_history = []

    try:
        while True:
            # ── Receive audio bytes from browser ──
            data = await websocket.receive_bytes()
            await websocket.send_text(json.dumps({"type": "status", "msg": "Samajh rahi hoon..."}))

            # ── STT ──
            loop = asyncio.get_event_loop()
            user_text = await loop.run_in_executor(None, transcribe_audio, data)

            if not user_text.strip():
                await websocket.send_text(json.dumps({"type": "error", "msg": "Kuch samajh nahi aaya, dobara bolein"}))
                continue

            print(f"👤 User: {user_text}")
            await websocket.send_text(json.dumps({"type": "transcript", "text": user_text}))
            await websocket.send_text(json.dumps({"type": "status", "msg": "Soch rahi hoon..."}))

            # ── Together AI - Streaming ──
            conversation_history.append({"role": "user", "content": user_text})

            full_reply = ""
            buffer = ""

            stream = together_client.chat.completions.create(
                model="meta-llama/Llama-3.3-70B-Instruct-Turbo-Free",
                messages=[{"role": "system", "content": SYSTEM_PROMPT}] + conversation_history,
                stream=True,
                max_tokens=200,
            )

            await websocket.send_text(json.dumps({"type": "status", "msg": "Bol rahi hoon..."}))

            # ── Stream text + generate TTS chunk by chunk ──
            for token in stream:
                chunk_text = token.choices[0].delta.content or ""
                full_reply += chunk_text
                buffer += chunk_text

                # Send text token to frontend immediately
                await websocket.send_text(json.dumps({"type": "text_chunk", "text": chunk_text}))

                # When buffer has a full sentence, generate TTS
                if any(p in buffer for p in ["।", ".", "!", "?", ",", ";"]):
                    sentences = split_into_sentences(buffer)

                    for sentence in sentences[:-1]:  # All complete sentences
                        if len(sentence.strip()) > 3:
                            print(f"🔊 TTS chunk: {sentence}")
                            wav_bytes = await loop.run_in_executor(
                                None, generate_tts_chunk, sentence
                            )
                            # Send audio chunk as base64
                            audio_b64 = base64.b64encode(wav_bytes).decode()
                            await websocket.send_text(json.dumps({
                                "type": "audio_chunk",
                                "audio": audio_b64
                            }))

                    # Keep incomplete last part in buffer
                    buffer = sentences[-1] if sentences else ""

            # ── Flush remaining buffer ──
            if buffer.strip() and len(buffer.strip()) > 3:
                wav_bytes = await loop.run_in_executor(None, generate_tts_chunk, buffer.strip())
                audio_b64 = base64.b64encode(wav_bytes).decode()
                await websocket.send_text(json.dumps({
                    "type": "audio_chunk",
                    "audio": audio_b64
                }))

            # ── Done ──
            conversation_history.append({"role": "assistant", "content": full_reply})
            print(f"🤖 Assistant: {full_reply}")
            await websocket.send_text(json.dumps({"type": "done", "full_text": full_reply}))

    except WebSocketDisconnect:
        print("🔌 Client disconnected")
    except Exception as e:
        print(f"❌ Error: {e}")
        await websocket.send_text(json.dumps({"type": "error", "msg": str(e)}))


# ─────────────────────────────────────────
# SERVE FRONTEND
# ─────────────────────────────────────────

@app.get("/")
async def get():
    with open("index.html", "r") as f:
        return HTMLResponse(f.read())


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)