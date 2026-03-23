# Research Paper Template

> Use this template for all TAMRS research papers.
> File naming: `YYYY-MM-{topic-slug}.md`
> Location: `.squad/research/papers/`

---

## Changelog

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | YYYY-MM-DD | {Agent} | Initial publication |

---

# {Paper Title}

**Status:** 🔬 [ACTIVE RESEARCH] / 📋 [DRAFT] / ✅ [PUBLISHED] / ⚠️ [SUPERSEDED] / 🏗️ [IMPLEMENTED]  
**Authors:** {Agent names}  
**Date:** YYYY-MM-DD  
**Related Issues:** #{issue-number}  
**Related Code:** `{path/to/relevant/code}`

---

## Abstract

*(≤200 words. State: what was investigated, how, and the key finding. Write last.)*

---

## 1. Background

*(What prompted this investigation? What existing knowledge exists? What gap does this address?)*

### 1.1 Context

*(Describe the system or situation that raised the research question)*

### 1.2 Prior Work

*(Reference existing docs, papers, or code that relate — use relative links where possible)*

- See also: `.squad/research/{related-file}.md`
- Issue: #{related-issue}

---

## 2. Research Question & Hypothesis

**Research Question:** *(One clear question this paper answers)*

**Hypothesis:** *(The falsifiable claim we are testing)*

> Example: "We hypothesize that agent fanout beyond 8 parallel tasks degrades response coherence in GPT-4o by >15% as measured by cross-reference consistency scores."

---

## 3. Methodology

*(How did we investigate? Enough detail that another team could reproduce this.)*

### 3.1 Experimental Setup

- Environment: *(describe system, tools, versions)*
- Duration: *(how long experiments ran)*
- Parameters varied: *(what we changed)*
- Parameters held constant: *(what we controlled for)*

### 3.2 Measurement Approach

*(What metrics were collected? How were they measured?)*

### 3.3 Limitations of Methodology

*(What could bias the results? What did we not measure?)*

---

## 4. Results

*(What we observed. Include data, logs, or code snippets.)*

### 4.1 Primary Findings

| Metric | Baseline | Experimental | Change |
|--------|----------|--------------|--------|
| {metric} | {value} | {value} | {%} |

### 4.2 Secondary Observations

*(Unexpected or interesting findings that don't directly answer the hypothesis)*

### 4.3 Raw Data

*(Link to data file or include inline if small)*

```json
// {topic}-data.json excerpt
{
  "experiment": "...",
  "results": [...]
}
```

---

## 5. Discussion

*(What do the results mean? Why did we see what we saw?)*

### 5.1 Interpretation

### 5.2 Implications for System Design

*(How should engineers change their approach based on this?)*

### 5.3 Surprising or Counterintuitive Findings

*(If any — be honest about what we got wrong in our hypothesis)*

---

## 6. Limitations

*(What did this study NOT cover? What could invalidate these findings?)*

- Sample size: *(if relevant)*
- Environment specificity: *(does this generalize?)*
- Time sensitivity: *(might this change as models evolve?)*
- Open questions: *(what would we need to investigate to be more confident?)*

---

## 7. Conclusions

*(The takeaways. Be direct and actionable.)*

1. **Finding 1:** ...
2. **Finding 2:** ...
3. **Recommendation:** ...

---

## 8. References

- [{title}]({relative-link-or-url})
- Issue #{number}: {title}
- Commit: `{sha}` — {description}

---

## Appendix

*(Optional: detailed data, full logs, code listings too long for the main text)*

---

*Template version: 1.0 | Maintained by Seven*
