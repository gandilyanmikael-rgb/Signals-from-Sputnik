# Signals from Sputnik: A Computational Study of Topics and Sentiment

What does Russian state media talk about when it writes for English-speaking audiences, and how does the tone of that coverage change as the war in Ukraine unfolds?

This project collects **5,511 English-language articles from Sputnik News** (December 30, 2021 – November 21, 2025) and uses **LDA topic modeling** and the **Lexicoder Sentiment Dictionary** to track which topics Sputnik covers and how negative each topic's coverage is over time, especially around the February 2022 invasion of Ukraine.

*Final project for GVPT628: Advanced Topics in Coding for Political Analysis, University of Maryland, Fall 2025.*

---

## Key Findings

- **Four topics** run through Sputnik's coverage: *Economic Confrontation*, *Global Partnerships*, *Political Confrontation*, and *Special Military Operation*.
- **Political Confrontation** and **Special Military Operation** were the most common topics in the corpus.
- **Special Military Operation coverage was the most negative** (about 60% of its sentiment-bearing words were negative), while **Global Partnerships was the least negative** (about 20%).
- Both the mix of topics and their tone **shifted noticeably around the February 2022 invasion**, and again roughly a year later.
- These patterns fit a **coordinated, top-down state communication strategy** rather than ordinary newsroom variation. The coverage paints Russia's adversaries and the war in harsh terms while presenting its partnerships in a positive light (see Ramsay & Robertshaw, 2019, on information flooding, strength projection and agenda-setting in state media).

## Methods

| Step | What it does | Tools |
|---|---|---|
| **1. Data collection** | Visits Sputnik's daily Russia-section archive pages, collects every article URL, then scrapes each article's title, date, summary and full text | `rvest`, `xml2`, `purrr` |
| **2. Cleaning** | Combines title, summary and body; removes URLs, image metadata, hex strings, standard stopwords and corpus-specific terms (e.g. "russia", "ukraine", "sputnik") that appear everywhere and would swamp the topics | `tidyverse`, `tidytext` |
| **3. Topic modeling** | Builds a document-term matrix and fits a 4-topic Latent Dirichlet Allocation model; each article is assigned its most likely topic | `topicmodels` |
| **4. Sentiment analysis** | Scores each article with the Lexicoder Sentiment Dictionary (LSD2015) and computes the share of sentiment-bearing words that are negative | `quanteda` |
| **5. Visualization** | Plots top terms per topic, topic frequency, monthly topic share, average negativity by topic, and monthly negativity by topic | `ggplot2` |

**Why Lexicoder?** General-purpose lexicons such as AFINN were built for everyday language. The Lexicoder Sentiment Dictionary (Young & Soroka, 2012) was built for political news coverage, so it captures the tone of political reporting more reliably.

## Repository Contents

```
├── README.md
├── sputnik_analysis.R          # Full pipeline: scraping, cleaning, LDA, sentiment, figures
└── data/
    └── sputnik_articles.zip    # The 5,511 scraped articles (CSV, ~115 MB unzipped)
```

The dataset has one row per article:

| Column | Description |
|---|---|
| `url` | Article URL on sputnikglobe.com |
| `title` | Headline |
| `articledate` | Publication date |
| `summary` | Lead/summary paragraph |
| `fulltext` | Full article body |

## How to Run

1. **Install R** (4.1 or later) and the required packages:

   ```r
   install.packages(c("tidyverse", "rvest", "xml2", "tidytext",
                      "topicmodels", "quanteda", "MetBrewer", "zoo"))
   ```

2. **Clone the repository** and open R in the project folder (so that `data/` is in the working directory).

3. **Run the script:**

   ```r
   source("sputnik_analysis.R")
   ```

   The script reads the zipped data directly, so you don't need to unzip it first. The LDA model uses a fixed seed (`123`), so you get the same topics every time you run it.

**Re-scraping the data (optional):** The web scraper is switched off by default because collecting all 5,511 articles takes about two hours. To re-collect the data yourself, set `RUN_SCRAPER <- TRUE` near the top of the script. Note that the live website may have changed since the original collection, so a fresh scrape may not exactly match the included dataset.

## Figures Produced

1. Topics by most dominant terms (top 14 terms per topic by β)
2. Topics by number of articles
3. Monthly share of Sputnik articles by topic
4. Average negativity by topic
5. Monthly average negativity by topic

## Limitations

- **Topic assignment is simplified.** LDA gives each article a mix of topics, and this analysis assigns each article only its single most likely topic.
- **Dictionary-based sentiment counts words, not meaning.** It can miss sarcasm, negation and context.
- **English-language coverage only.** Sputnik's English output is aimed at foreign audiences and may differ from its Russian-language reporting.
- **One section of the site.** Articles were collected from Sputnik's Russia section archive, not the entire site.

## References

- Feinberg, A. (2017). My life at a Russian propaganda network. *Politico Magazine*.
- Ramsay, G., & Robertshaw, S. (2019). *Weaponising News: RT, Sputnik and Targeted Disinformation*. King's College London.
- Young, L., & Soroka, S. (2012). Affective news: The automated coding of sentiment in political texts. *Political Communication*, 29(2), 205–231.

## Author

**Mikael Gandilyan**, M.S. Applied Political Analytics, University of Maryland
[LinkedIn](https://www.linkedin.com/in/mikael-gandilyan)

*The scraped articles are included for research and replication purposes only. All article content belongs to its original publisher.*
