"""
📊 ניתוח נתונים — Kids Squad
מיועד לגילאי 14+

פרויקט התחלתי: ניתוח ציונים בכיתה
אפשר לשנות את הנתונים ולהוסיף גרפים!

💡 רוצה עזרה? תגיד:
   "מתכנת, תסביר לי מה עושה כל שורה"
   "חוקר, תעזור לי להוסיף ניתוח סטטיסטי"
"""

# ===== ייבוא ספריות =====
# אם חסרה ספריה, תריץ בטרמינל: pip install matplotlib
import json
import os
from datetime import datetime

# ===== נתוני דוגמה — שנה לנתונים שלך! =====
students_data = {
    "תלמידים": [
        {"שם": "דני",  "מתמטיקה": 85, "אנגלית": 72, "מדעים": 91, "היסטוריה": 78},
        {"שם": "נועה",  "מתמטיקה": 92, "אנגלית": 88, "מדעים": 95, "היסטוריה": 84},
        {"שם": "יוסי",  "מתמטיקה": 67, "אנגלית": 75, "מדעים": 71, "היסטוריה": 69},
        {"שם": "מיכל", "מתמטיקה": 94, "אנגלית": 91, "מדעים": 88, "היסטוריה": 96},
        {"שם": "אדם",  "מתמטיקה": 78, "אנגלית": 82, "מדעים": 74, "היסטוריה": 80},
        {"שם": "שרה",  "מתמטיקה": 88, "אנגלית": 85, "מדעים": 92, "היסטוריה": 87},
    ]
}

SUBJECTS = ["מתמטיקה", "אנגלית", "מדעים", "היסטוריה"]


def calculate_average(student: dict) -> float:
    """חישוב ממוצע ציונים לתלמיד"""
    grades = [student[subject] for subject in SUBJECTS]
    return sum(grades) / len(grades)


def find_best_student() -> tuple[str, float]:
    """מצא את התלמיד עם הממוצע הכי גבוה"""
    best_name = ""
    best_avg = 0
    for student in students_data["תלמידים"]:
        avg = calculate_average(student)
        if avg > best_avg:
            best_avg = avg
            best_name = student["שם"]
    return best_name, best_avg


def find_hardest_subject() -> tuple[str, float]:
    """מצא את המקצוע הכי קשה (ממוצע הכי נמוך)"""
    subject_averages = {}
    for subject in SUBJECTS:
        total = sum(s[subject] for s in students_data["תלמידים"])
        subject_averages[subject] = total / len(students_data["תלמידים"])

    hardest = min(subject_averages, key=subject_averages.get)
    return hardest, subject_averages[hardest]


def generate_report() -> str:
    """יצירת דו\"ח ניתוח מלא"""
    report_lines = []
    report_lines.append("=" * 50)
    report_lines.append("📊 דו\"ח ניתוח ציונים — Kids Squad")
    report_lines.append(f"📅 תאריך: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    report_lines.append("=" * 50)
    report_lines.append("")

    # ממוצע לכל תלמיד
    report_lines.append("📋 ממוצעים לפי תלמיד:")
    report_lines.append("-" * 30)
    for student in students_data["תלמידים"]:
        avg = calculate_average(student)
        # הוסף אימוג'י לפי ציון
        if avg >= 90:
            emoji = "🌟"
        elif avg >= 80:
            emoji = "👍"
        elif avg >= 70:
            emoji = "📝"
        else:
            emoji = "💪"
        report_lines.append(f"  {emoji} {student['שם']}: {avg:.1f}")

    report_lines.append("")

    # ממוצע לכל מקצוע
    report_lines.append("📚 ממוצעים לפי מקצוע:")
    report_lines.append("-" * 30)
    for subject in SUBJECTS:
        total = sum(s[subject] for s in students_data["תלמידים"])
        avg = total / len(students_data["תלמידים"])
        bar = "█" * int(avg / 5)  # בר גרפי פשוט
        report_lines.append(f"  {subject}: {avg:.1f}  {bar}")

    report_lines.append("")

    # תלמיד מצטיין
    best_name, best_avg = find_best_student()
    report_lines.append(f"🏆 תלמיד מצטיין: {best_name} (ממוצע: {best_avg:.1f})")

    # מקצוע מאתגר
    hard_subj, hard_avg = find_hardest_subject()
    report_lines.append(f"📉 המקצוע הכי מאתגר: {hard_subj} (ממוצע: {hard_avg:.1f})")

    report_lines.append("")
    report_lines.append("=" * 50)

    return "\n".join(report_lines)


def save_report(report: str, filename: str = "report.txt"):
    """שמור את הדו\"ח לקובץ"""
    filepath = os.path.join(os.path.dirname(__file__), filename)
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(report)
    print(f"💾 הדו\"ח נשמר ב: {filepath}")


def try_matplotlib():
    """נסה ליצור גרף עם matplotlib (אם מותקנת)"""
    try:
        import matplotlib.pyplot as plt
        import matplotlib

        matplotlib.rcParams["font.family"] = "DejaVu Sans"

        students = [s["שם"] for s in students_data["תלמידים"]]
        averages = [calculate_average(s) for s in students_data["תלמידים"]]

        colors = ["#667eea", "#764ba2", "#f093fb", "#f5576c", "#00b894", "#fdcb6e"]

        plt.figure(figsize=(10, 6))
        bars = plt.bar(students, averages, color=colors[: len(students)])

        # Add value labels on bars
        for bar, avg in zip(bars, averages):
            plt.text(
                bar.get_x() + bar.get_width() / 2,
                bar.get_height() + 1,
                f"{avg:.1f}",
                ha="center",
                fontsize=12,
            )

        plt.title("Student Grade Averages", fontsize=16)
        plt.ylabel("Average Grade", fontsize=12)
        plt.ylim(0, 105)
        plt.grid(axis="y", alpha=0.3)

        chart_path = os.path.join(os.path.dirname(__file__), "grades_chart.png")
        plt.savefig(chart_path, dpi=150, bbox_inches="tight")
        plt.close()
        print(f"📈 גרף נשמר ב: {chart_path}")
        return True
    except ImportError:
        print("💡 רוצה גרפים? תריץ: pip install matplotlib")
        return False


# ===== הרצה ראשית =====
if __name__ == "__main__":
    print("🚀 Kids Squad — ניתוח נתונים")
    print()

    # יצירת דו"ח
    report = generate_report()
    print(report)

    # שמירה לקובץ
    save_report(report)

    # נסה ליצור גרף
    try_matplotlib()

    print()
    print("🎓 רוצה להרחיב? תגיד:")
    print('   "חוקר, תוסיף ניתוח לפי מגדר"')
    print('   "מתכנת, תוסיף קריאה מקובץ CSV"')
    print('   "מעצב, תשפר את הגרפים"')
