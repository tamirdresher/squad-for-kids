# 🌍 Curriculum Lookup Skill

> Find the right curriculum standards for any country, grade level, and subject.

## Purpose

This skill helps the Squad for Kids system determine what a child should be learning based on their geographic location and grade level. It maps country + grade → curriculum → subjects → topics.

---

## How to Use

### Input
- **Country** (ISO code or name): e.g., `US`, `IL`, `UK`, `AU`
- **Grade/Year**: The child's current grade level
- **State/Province** (optional): For countries with regional curricula (US, Canada, Australia)

### Output
- Curriculum name and authority
- List of subjects for that grade
- Key topics/skills per subject
- Academic calendar (when the school year starts/ends)
- Grade naming convention (e.g., US "Grade 2" = UK "Year 3" = IL "כיתה ב")

---

## Known Curriculum Mappings

### 🇺🇸 United States — Common Core State Standards

**Authority:** National Governors Association / Council of Chief State School Officers  
**Calendar:** September – June  
**Grade system:** Kindergarten (K), then Grade 1–12

| Grade | Age | Key Subjects |
|-------|-----|-------------|
| K | 5-6 | Reading (phonics, sight words), Math (counting to 100, shapes), Science (weather, animals), Social Studies (community) |
| 1 | 6-7 | Reading (fluency), Math (addition/subtraction to 20), Science (materials, light/sound), Social Studies (maps) |
| 2 | 7-8 | Reading (comprehension), Math (place value, addition to 100), Science (habitats, earth), Social Studies (history) |
| 3 | 8-9 | Reading (chapter books), Math (multiplication, fractions intro), Science (forces, life cycles), Social Studies (government) |
| 4 | 9-10 | Reading (inference, analysis), Math (multi-digit operations, fractions), Science (energy, earth systems), Social Studies (state history) |
| 5 | 10-11 | Reading (literary analysis), Math (decimals, volume), Science (matter, ecosystems), Social Studies (US history) |
| 6 | 11-12 | ELA (argumentative writing), Math (ratios, expressions), Science (cells, earth science), Social Studies (world cultures) |
| 7 | 12-13 | ELA (research writing), Math (proportional relationships), Science (chemistry basics), Social Studies (geography) |
| 8 | 13-14 | ELA (literary criticism), Math (linear equations, functions), Science (physics intro), Social Studies (US government) |
| 9-12 | 14-18 | English, Algebra/Geometry/Calculus, Biology/Chemistry/Physics, US/World History, Electives |

**Web search query if more detail needed:**  
`"Common Core standards grade {N} subjects topics {year}"`

### 🇬🇧 United Kingdom — National Curriculum (England)

**Authority:** Department for Education  
**Calendar:** September – July (3 terms)  
**Grade system:** Reception, then Year 1–13

| Year | US Equivalent | Age | Key Stage | Key Subjects |
|------|--------------|-----|-----------|-------------|
| Reception | K | 4-5 | EYFS | Literacy, Numeracy, Understanding the World, Expressive Arts |
| 1 | Grade 1 | 5-6 | KS1 | English (phonics), Maths (numbers to 100), Science (plants, animals) |
| 2 | Grade 2 | 6-7 | KS1 | English (writing), Maths (addition/subtraction), Science (materials, habitats) |
| 3 | Grade 3 | 7-8 | KS2 | English (reading comprehension), Maths (multiplication tables), Science (rocks, light) |
| 4 | Grade 4 | 8-9 | KS2 | English (grammar), Maths (fractions, decimals), Science (sound, electricity) |
| 5 | Grade 5 | 9-10 | KS2 | English (analysis), Maths (percentages), Science (forces, space) |
| 6 | Grade 6 | 10-11 | KS2 | English (SATs prep), Maths (algebra intro), Science (evolution, body systems) |
| 7-9 | Grade 7-9 | 11-14 | KS3 | English, Maths, Science, History, Geography, Languages, Technology, Arts |
| 10-11 | Grade 10-11 | 14-16 | KS4 (GCSE) | Core + options, GCSE examinations |
| 12-13 | Grade 12-13 | 16-18 | KS5 (A-Level) | 3-4 A-Level subjects |

**Web search query:** `"UK National Curriculum Year {N} subjects topics"`

### 🇮🇱 Israel — Ministry of Education (משרד החינוך)

**Authority:** Israeli Ministry of Education (משרד החינוך)  
**Calendar:** September (אלול) – June  
**Grade system:** כיתה א׳ – כיתה י״ב (Kitah Aleph – Kitah Yod-Bet)

| כיתה | Grade | Age | Key Subjects |
|------|-------|-----|-------------|
| א׳ | 1 | 6-7 | קריאה וכתיבה (Reading/Writing Hebrew), חשבון (Math: numbers to 100), מדעים (Science), מולדת חברה (Homeland/Society) |
| ב׳ | 2 | 7-8 | קריאה (Reading fluency), חשבון (Math: addition/subtraction), מדעים (Nature), תנ״ך (Bible studies intro) |
| ג׳ | 3 | 8-9 | עברית (Hebrew language), חשבון (Multiplication), מדעים (Science experiments), תנ״ך (Bible), אנגלית (English intro) |
| ד׳ | 4 | 9-10 | עברית, חשבון (Fractions), מדעים וטכנולוגיה, תנ״ך, אנגלית, היסטוריה (History intro) |
| ה׳ | 5 | 10-11 | עברית, מתמטיקה, מדעים, תנ״ך, אנגלית, היסטוריה, גיאוגרפיה |
| ו׳ | 6 | 11-12 | עברית, מתמטיקה, מדעים, תנ״ך, אנגלית, היסטוריה, אזרחות intro |
| ז׳-ט׳ | 7-9 | 12-15 | חטיבת ביניים: Hebrew, Math, English, Science, Bible, History, Civics, Technology |
| י׳-י״ב | 10-12 | 15-18 | בגרויות (Bagrut exams): Hebrew, Math, English, Bible, History, Civics + electives |

**Web search query:** `"תכנית לימודים כיתה {N} משרד החינוך נושאים"`

### 🇦🇺 Australia — Australian Curriculum (ACARA)

**Authority:** Australian Curriculum, Assessment and Reporting Authority  
**Calendar:** February – December (4 terms)  
**Grade system:** Foundation (Prep), then Year 1–12

| Year | Age | Key Subjects |
|------|-----|-------------|
| Foundation | 5-6 | English (phonics), Mathematics (counting), Science (objects, living things), HASS (personal history) |
| 1-2 | 6-8 | English, Mathematics, Science, HASS (History and Social Sciences), Technologies, The Arts, Health & PE |
| 3-4 | 8-10 | English, Mathematics, Science, HASS, Technologies, The Arts, Languages, Health & PE |
| 5-6 | 10-12 | English, Mathematics, Science, HASS, Technologies, The Arts, Languages, Health & PE |
| 7-10 | 12-16 | English, Mathematics, Science, HASS, Technologies, The Arts, Languages, Health & PE |
| 11-12 | 16-18 | State-based: ATAR/VCE/HSC/QCE subjects |

**Web search query:** `"Australian Curriculum Year {N} content descriptions"`

### 🇨🇦 Canada — Provincial Curricula

**Note:** Canada has NO national curriculum. Each province sets its own.

**Key provinces:**
- **Ontario:** The Ontario Curriculum (Grade 1-12)
- **British Columbia:** BC Curriculum (K-12)
- **Alberta:** Alberta Programs of Study
- **Quebec:** Programme de formation (French language)

**Web search query:** `"{province} curriculum grade {N} subjects expectations"`

### 🇮🇳 India — CBSE / ICSE

**Authority:** CBSE (Central Board) or ICSE (Council for Indian School Certificate)  
**Calendar:** April – March  
**Grade system:** Class 1–12 (Standards)

**Web search query:** `"CBSE syllabus class {N} subjects chapters {year}"`

---

## Lookup Process

### Step 1: Country Detection
From the kid's city, determine the country:
- Use common knowledge (e.g., "Tel Aviv" → Israel, "London" → UK)
- If ambiguous, ask: "Which country is {city} in?"

### Step 2: Grade Normalization
Convert the kid's stated grade to a number:
- "2nd grade" → 2
- "Year 3" → 2 (UK Year = US Grade + 1)
- "כיתה ב׳" → 2
- "Class 4" → 4

### Step 3: Curriculum Lookup
1. Check the known mappings above
2. If the country isn't listed, use web search:
   ```
   "{country} national curriculum grade {N} subjects {year}"
   ```
3. Extract: subject list, key topics, academic calendar

### Step 4: Subject Mapping
Map discovered subjects to Squad agent roles:

| Agent Role | Typical Subjects |
|-----------|-----------------|
| Head Teacher | Oversees all, focus on core literacy + numeracy |
| Subject Helper | Math, Science, Language Arts, Social Studies |
| Creative Coach | Art, Music, Drama, Creative Writing, Projects |
| Fun & Games | Gamified practice for ALL subjects |
| Study Buddy | Social-emotional learning, Life skills |

### Step 5: Academic Calendar
Determine `nextGradeDate` based on the country's school calendar:

| Region | Typical Grade Transition |
|--------|------------------------|
| Northern Hemisphere (US, UK, Israel, Canada, Europe) | September 1 |
| Southern Hemisphere (Australia, NZ, South Africa) | February 1 |
| Japan, South Korea | April 1 |
| India | April 1 |

---

## When Web Search is Needed

Use web search when:
1. Country is not in the known mappings above
2. You need specific topic details for a subject at a given grade
3. Curriculum has been recently updated
4. The kid mentions a specific curriculum board not listed here
5. Regional variations exist (US state standards, Canadian provinces)

**Search strategy:**
```
1. Try: "{country} {curriculum_name} grade {N} syllabus {current_year}"
2. Try: "{country} education standards {grade} subjects"
3. Try: "{country} primary/secondary curriculum overview"
```
