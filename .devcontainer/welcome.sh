#!/bin/bash
# 🎓 Kids Squad — Welcome Script
# סקריפט ברוכים הבאים

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║                                                  ║"
echo "║   🚀  !ברוכים הבאים ל-Kids Squad                ║"
echo "║                                                  ║"
echo "║   הסביבה שלך מוכנה!                              ║"
echo "║   Your environment is ready!                     ║"
echo "║                                                  ║"
echo "║   📝 שלב הבא:                                   ║"
echo "║   פתח את Copilot Chat ותכתוב: שלום              ║"
echo "║                                                  ║"
echo "║   Next step:                                     ║"
echo "║   Open Copilot Chat and type: שלום               ║"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Install any project dependencies if they exist
if [ -f "package.json" ]; then
  npm install --silent 2>/dev/null
fi

if [ -f "requirements.txt" ]; then
  pip install -r requirements.txt --quiet 2>/dev/null
fi

# Create a welcome file that opens automatically
cat > WELCOME.md << 'EOF'
# 🚀 !ברוכים הבאים ל-Kids Squad

## מה עכשיו?

1. **פתח את Copilot Chat** — לחץ על הצ'אט למעלה מימין (או `Ctrl+Shift+I`)
2. **תכתוב:** `שלום`
3. **עקוב אחרי ההוראות** — ה-AI ינחה אותך צעד אחר צעד!

## What now?

1. **Open Copilot Chat** — Click the chat icon (top right) or press `Ctrl+Shift+I`
2. **Type:** `שלום` (or `hello`)
3. **Follow the guide** — The AI will walk you through setup step by step!

---
🎓 **Kids Squad** — צוות AI שעוזר לך ללמוד, לבנות וליצור!
EOF

echo "✅ Ready! Open Copilot Chat and type: שלום"
