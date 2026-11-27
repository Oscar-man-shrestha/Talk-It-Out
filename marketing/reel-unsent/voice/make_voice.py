"""Voiceover for the real-screenshot feature tour.

Voice: Kokoro-82M (Apache-2.0), voice "af_heart", run locally with kokoro-onnx.
Model files go in voice/model/ (kokoro-v1.0.onnx, voices-v1.0.bin from
https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.0).

    python make_voice.py   # -> ../talk-it-out-feature-tour-real-voice.mp4
"""

from __future__ import annotations

import subprocess
import sys
import wave
from pathlib import Path

import numpy as np
from kokoro_onnx import Kokoro

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
VIDEO = ROOT / "talk-it-out-feature-tour-real.mp4"
OUT = ROOT / "talk-it-out-feature-tour-real-voice.mp4"
VOICE, SPEED = "af_heart", 1.05
SR = 44100

# (start, must end by, line)
LINES = [
    (0.4, 2.75, "We've all typed this message."),
    (2.9, 4.55, "And then deleted it."),
    (4.65, 6.7, "Because being honest at work feels risky."),
    (6.9, 10.1, "Meet Talk It Out. Say what you really think, kindly."),
    (10.35, 15.4, "Your team's conversations live in groups. You only join when you accept an invite."),
    (15.8, 22.9, "Type what's on your mind, and tick Anonymous. The group won't see your name. Only the controller can."),
    (23.3, 31.9, "AI rewrites the tone, but never the meaning. Then the group's controller reviews it, and publishes the kind version."),
    (32.3, 37.4, "The group sees an anonymous user. You track your message status, privately."),
    (37.8, 46.4, "And it's a real group chat, with reactions, replies, polls, pins, photos with hidden details removed, and mentions."),
    (46.8, 51.4, "Missed a discussion? Catch up shows the key points in seconds."),
    (51.8, 58.9, "Find teammates by name or handle, even with a typo, or simply share an invite link."),
    (59.3, 66.4, "Ask the wider community. The most helpful answers rise to the top."),
    (66.8, 70.9, "Notifications keep you in the loop."),
    (71.3, 75.4, "Block anyone. Contributors never see each other's original words."),
    (75.8, 81.4, "Sign in with Google or email, and reset your password with a code."),
    (82.0, 87.6, "Talk It Out. Speak up. Stay kind."),
]


def resample(x, sr_in, sr_out):
    n = int(len(x) * sr_out / sr_in)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x).astype(np.float32)


def synth(k, text, room):
    speed = SPEED
    while True:
        s, sr = k.create(text, voice=VOICE, speed=speed, lang="en-us")
        s = resample(np.asarray(s, np.float32), sr, SR)
        # Trim leading/trailing silence.
        idx = np.where(np.abs(s) > 0.01)[0]
        if len(idx):
            s = s[max(0, idx[0] - 600): idx[-1] + 2400]
        if len(s) / SR <= room or speed >= 1.25:
            return s, speed
        speed = round(speed + 0.05, 2)


def music_track():
    sys.path.insert(0, str(ROOT))
    import make_real_tour as M
    return M.build_audio(), M.DUR


def main():
    k = Kokoro(str(HERE / "model" / "kokoro-v1.0.onnx"), str(HERE / "model" / "voices-v1.0.bin"))
    music, dur = music_track()
    n = int(dur * SR)
    vo = np.zeros(n, np.float32)
    for start, end, text in LINES:
        s, speed = synth(k, text, end - start)
        i = int(start * SR)
        j = min(n, i + len(s))
        vo[i:j] += s[: j - i]
        fits = "ok" if start + len(s) / SR <= end + 0.05 else "LONG"
        print(f"{start:5.1f}s  {len(s) / SR:4.1f}s  speed {speed}  {fits}  {text[:48]}")
    vo /= np.max(np.abs(vo)) + 1e-9
    # Duck the music under the voice (smoothed envelope, about -9 dB).
    env = np.convolve(np.abs(vo) > 0.02, np.ones(int(0.25 * SR)) / (0.25 * SR), mode="same")
    env = np.clip(env * 3, 0, 1)
    gain = 1.0 - 0.64 * env
    mix = music[:n] * 0.62 * gain + vo * 0.95
    mix /= np.max(np.abs(mix)) + 1e-9
    mix *= 0.89
    wav = HERE / "voice-mix.wav"
    pcm = (np.clip(mix, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(wav), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(np.stack([pcm, pcm], axis=1).tobytes())
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error", "-i", str(VIDEO), "-i", str(wav),
        "-map", "0:v", "-map", "1:a", "-c:v", "copy",
        "-af", "loudnorm=I=-14:TP=-1.5:LRA=11", "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
        "-movflags", "+faststart", "-shortest", str(OUT),
    ], check=True)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
