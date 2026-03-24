# Prompt: Record REAL Squad for Kids Demo Videos

Paste this entire prompt into a fresh Copilot CLI session on a machine with a browser.

---

## Context

I need to record REAL demo videos of Squad for Kids — actual screen recordings of GitHub Copilot Chat in a Codespace, NOT mockups or animations.

The Codespace is: `demo-screenshots-75w9r5pr5cpr45` at `https://demo-screenshots-75w9r5pr5cpr45.github.dev/`
Repo: tamirdresher/squad-for-kids

I have 4 conversations to record (the AI responses are already proven to work — we tested them). The videos should be ~55 seconds each with narration.

## Critical Learnings (from previous failed attempts)

### What DOESN'T work:
- ❌ ffmpeg gdigrab — captures desktop, not browser
- ❌ PIL/Python chat simulations — looks fake, not a real Codespace
- ❌ Regular `playwright-cli click` on VS Code elements — pointer-block overlay intercepts all clicks

### What DOES work:
- ✅ `playwright-cli video-start` / `video-stop` — records actual browser content as .webm
- ✅ `playwright-cli screenshot` — perfect high-quality captures
- ✅ Force-click: `playwright-cli run-code "async(p)=>{await p.locator('aria-ref=XXXX').click({force:true});}"`
- ✅ Hebrew input: `playwright-cli run-code "async(p)=>{await p.keyboard.insertText('Hebrew text');}"` (NOT `type`)
- ✅ English input: `playwright-cli type "English text"` (after force-clicking the input)

### VS Code Layout Setup (MUST DO BEFORE RECORDING):
1. Dismiss recovery dialog if present (click "Cancel" button)
2. Close ALL editor tabs: `playwright-cli press "Control+Shift+p"` → type "View: Close All Editors" → Enter
3. Close sidebar: `playwright-cli press "Control+b"`
4. Close terminal: `playwright-cli press "Control+j"`
5. MAXIMIZE the chat panel: find "Maximize Secondary Side Bar" button in snapshot, force-click it
6. New chat: `playwright-cli press "Control+l"`

### Chat Input Interaction:
1. Take snapshot to find the chat input ref: `playwright-cli snapshot --filename=snap.yaml`
2. Search for: `textbox "Chat Input"` — note the ref (e.g., e413)
3. Force-click it: `playwright-cli run-code "async(p)=>{await p.locator('aria-ref=e413').click({force:true});}"`
4. Type English: `playwright-cli type "message text"`
5. Type Hebrew: `playwright-cli run-code "async(p)=>{await p.keyboard.insertText('Hebrew text');}"`
6. Send: `playwright-cli press "Enter"`
7. Wait 25-30 seconds for AI response
8. Take snapshot to read the response text

## Recording Pipeline (per video):

```
1. playwright-cli open https://demo-screenshots-75w9r5pr5cpr45.github.dev/ --persistent
   # OR connect to existing browser session
   
2. [Do layout setup steps above]

3. playwright-cli video-start

4. [Force-click chat input]
5. [Type the kid's message — slowly, ~3 chars/sec for visual effect]
6. playwright-cli press "Enter"
7. Start-Sleep 30  # wait for full AI response

8. [Force-click chat input again]
9. [Type the kid's answer]
10. playwright-cli press "Enter"
11. Start-Sleep 25

12. playwright-cli video-stop
    # Saves as .webm in .playwright-cli/ folder

13. # Post-process:
    edge-tts --voice "VOICE" --rate "+15%" --text "NARRATION" --write-media narration.mp3
    ffmpeg -i raw.webm -i narration.mp3 -c:v libx264 -c:a aac -shortest FINAL.mp4
```

## The 4 Demos to Record:

### 1. English Minecraft (demo-boy-en.mp4)
**Character:** Jake, 9, California, loves Minecraft
**Message 1:** "Hi! My name is Jake, I'm 9 years old from California. I LOVE Minecraft! Can you help me learn multiplication using Minecraft?"
**Expected AI:** Minecraft multiplication adventure with blocks, torches, farms + challenge (7×3, 6×5, 9×2)
**Message 2:** "I think I got it! 7x3=21, 6x5=30, 9x2=18! Am I right?"
**Expected AI:** "100% right! 🎉⛏️" with checkmarks
**Narration voice:** en-US-GuyNeural
**Narration:** "Meet Jake, nine years old, who loves Minecraft. He opens Squad for Kids and asks for help with multiplication. The AI creates a personalized Minecraft math adventure — teaching multiplication through building walls, crafting torches, and farming. Jake answers the challenge... seven times three is twenty-one, six times five is thirty, nine times two is eighteen. And the AI celebrates — all correct! Like a Minecraft pro! Squad for Kids turns any interest into a learning adventure."

### 2. English Frozen (demo-girl-en.mp4)
**Character:** Emma, 8, loves Frozen and Elsa
**Message 1:** "Hi! My name is Emma, I am 8 years old. I love Frozen and Elsa! Can you help me learn English words about winter and snow?"
**Expected AI:** 12 vocabulary words + Frozen sentences + fill-in-blank quiz
**Message 2:** "I know! A scarf on my neck, frozen water is ice, and the cold season is winter! Like in Frozen!"
**Expected AI:** "Elsa would be proud! 💙" + 5 more words
**Narration voice:** en-US-JennyNeural
**Narration:** "Meet Emma, eight years old, who loves Frozen and Elsa. She asks Squad for Kids to help her learn English words about winter. The AI creates a Frozen-themed vocabulary lesson — snow, ice, frost, boots, snowman — twelve winter words with simple definitions. Then a quiz: fill in the blanks, Frozen style! Emma answers them all... and the AI says Elsa would be proud! Every child gets their own magical learning adventure."

### 3. Hebrew Minecraft (demo-boy-he.mp4)
**Character:** יואב, 8, loves Minecraft
**Message 1 (use insertText):** "שלום! קוראים לי יואב, אני בן 8. אני אוהב מיינקראפט! תלמד אותי כפל?"
**Expected AI:** Multiplication with diamonds in chests, tricks, challenge 3×6
**Message 2 (use insertText):** "אני חושב ש 3 כפול 6 זה 18! כי 6+6+6=18. נכון?"
**Expected AI:** "אלוףףף! 💪" + next level
**Narration voice:** he-IL-AvriNeural
**Narration:** "הכירו את יואב, בן 8, שמאוד אוהב מיינקראפט. הוא פותח את סקוואד לילדים ומבקש עזרה בכפל. הבינה המלאכותית יוצרת הרפתקת כפל במיינקראפט - עם יהלומים בתיבות, טריקים חכמים, ואתגר. יואב עונה... שלוש כפול שש זה שמונה עשרה! והתשובה נכונה! אלוף! סקוואד לילדים הופך כל תחביב להרפתקת למידה."

### 4. Hebrew Frozen (demo-girl-he.mp4)
**Character:** נועה, 8, loves Frozen and Elsa
**Message 1 (use insertText):** "היי! קוראים לי נועה, אני בת 8. אני מאוד אוהבת את פרוזן ואת אלזה! תלמדי אותי מילים באנגלית על חורף ושלג?"
**Expected AI:** 10 English words with Hebrew pronunciation guides + quiz
**Message 2 (use insertText):** "שלג זה snow! קרח זה ice! וחורף זה winter! נכון?"
**Expected AI:** "את אלופה באנגלית! 👑"
**Narration voice:** he-IL-HilaNeural
**Narration:** "הכירו את נועה, בת 8, שמאוד אוהבת את פרוזן ואת אלזה. היא מבקשת מסקוואד לילדים ללמד אותה מילים באנגלית על חורף ושלג. הבינה המלאכותית יוצרת שיעור אנגלית בסגנון פרוזן - עם עשר מילים חדשות, הגייה, ומשפטים של אלזה. ואז חידון! שלג זה סנואו, קרח זה אייס, חורף זה וינטר. נועה ענתה נכון על הכל! אלופה באנגלית! סקוואד לילדים הופך כל תחביב להרפתקת למידה."

## Output:
- Save final videos to C:\temp\squad-for-kids\docs\ as demo-boy-en.mp4, demo-girl-en.mp4, demo-boy-he.mp4, demo-girl-he.mp4
- git add, commit "feat: real Codespace demo recordings", push

## Important Notes:
- The narration MUST be written AFTER seeing the actual AI response. The scripts above are based on proven responses but the AI may say something slightly different. Watch the raw recording, adjust narration to match.
- Record FIRST, narrate SECOND. Never the other way around.
- If the Codespace is stopped, click "Restart codespace" and wait 60s.
- The AI responses start with a Hebrew greeting ("שלום! ברוכים הבאים ל-Kids Squad!") even for English conversations because the repo's copilot-instructions.md is in Hebrew. This is fine — the AI switches to English after the greeting.
- Each video should be ~55 seconds total.
- Use `--rate "+15%"` on edge-tts so narration isn't too slow.

Do all 4 videos autonomously. Don't ask me questions. If something fails, debug and retry. If the Codespace won't start, create a new one from the squad-for-kids repo.
