#GVPT628:Research Project
#Gandilyan, Mikael
#2025-11-24

## Packages
library(rvest)
library(tidyverse)
library(MetBrewer)
library(zoo)
library(tidytext)
library(topicmodels)
library(quanteda)


## Here is the whole Sputnik extravaganza
#Scraping all 5,511 Sputnik articles takes about two hours, so it is switched off by
#default. The scraped data is included in data/sputnik_articles.zip and is loaded below.
#Set RUN_SCRAPER to TRUE only if you want to re-collect the articles yourself.
RUN_SCRAPER <- FALSE

if (RUN_SCRAPER) {
#START CODE
options(timeout = 60)
library(rvest)
library(xml2)
library(purrr)
library(dplyr)
library(stringr)

get_sputnik_urls_date <- function(date) {
  base_url  <- "https://sputnikglobe.com"
  date_str  <- format(date, "%Y%m%d")  # e.g. "20220403"
  list_url  <- paste0(base_url, "/services/russia/?date=", date_str)
  
  webpage <- read_html(list_url)
  
  sputnik_urls <- webpage |>
    html_elements("div.list__content > a") |>
    html_attr("href") |>
    url_absolute(base_url)   # make them absolute
  
  return(sputnik_urls)
}

safe_text <- function(page, css, collapse = NULL) {
  nodes <- html_elements(page, css)
  if (length(nodes) == 0) return(NA_character_)
  txt <- html_text(nodes)
  if (!is.null(collapse)) txt <- str_c(txt, collapse = collapse)
  txt
}

sputnikParser <- function(url) {
  page <- read_html(url)
  
  title <- safe_text(page, "div.article__header > h1")
  
  articledate_raw <- safe_text(page, "div.article__info > div > a")
  # i need to convert the weird date format into something that is readable
  date_str <- str_extract(articledate_raw, "\\d{2}\\.\\d{2}\\.\\d{4}")
  articledate <- as.Date(date_str, format = "%d.%m.%Y")
  
  summary <- safe_text(page, "div.article__announce-text", collapse = "\n")
  
  fulltext <- safe_text(page, "div.article__body div", collapse = "\n")
  
  data.frame(
    url        = url,
    title      = title,
    articledate = articledate,
    summary    = summary,
    fulltext   = fulltext,
    stringsAsFactors = FALSE
  )
}

start_date <- as.Date("2022-01-01")
end_date   <- Sys.Date()   

all_dates <- seq(start_date, end_date, by = "day")
length(all_dates)  # just to see how many days

all_sputnik_urls <- map(all_dates, get_sputnik_urls_date) |>
  unlist() |>
  unique()

length(all_sputnik_urls) #just to see how many total unique sputnik article urls we have

all_sputnik_articles <- map_dfr(all_sputnik_urls, function(u) {
  Sys.sleep(0.1)
  sputnikParser(u)
})
#END CODE

## Sorting and saving the data
sputnik_articles <- all_sputnik_articles|>
  arrange(articledate)
write_csv(sputnik_articles, "data/sputnik_articles.csv")
}

## Loading the data (reads the zipped file directly if it has not been unzipped)
data_path <- if (file.exists("data/sputnik_articles.csv")) {
  "data/sputnik_articles.csv"
} else {
  "data/sputnik_articles.zip"
}
sputnik_articles <- read_csv(data_path)


##topic modeling
sputnik_articles <- sputnik_articles|>
  mutate(
    text_all = str_to_lower(paste(title, summary, fulltext, sep = " "))
  )
clean_articles <- sputnik_articles|>
  mutate(
    text_all = str_to_lower(text_all),
    text_all = str_remove_all(text_all, "https?://[^\\s]+"),       # remove URLs
    text_all = str_remove_all(text_all, "\\S*\\.\\S*"),           # remove domain-like tokens
    text_all = str_remove_all(text_all, "\\b(img|image|jpg|jpeg|png|gif|cdn\\d*)\\b"),
    text_all = str_remove_all(text_all, "\\b[0-9a-f]{4,}\\b")     # remove hex-like strings
  )

my_stopwords <- tibble::tibble(
  word = c(
    # new junk terms from metadata
    "type", "imageobject", "url", "context",
    "height", "width", "thumbnail", "gmt", "russian", "russia", "president",
    "video", "ukraine", "ukrainian", "sputnik", "european", "eu",
    "view", "javascript", "browser", "vladimir", "photo", "ruptly", "web", "media",
    "indian", "live"
  )
)

tokens <- clean_articles|>
  select(url, text_all)|>
  unnest_tokens(word, text_all)|>
  filter(stringr::str_detect(word, "^[a-z]+$"))|>
  anti_join(stop_words,   by = "word") %>%
  anti_join(my_stopwords, by = "word")  

dtm <- tokens|>
  count(url, word)|>
  cast_dtm(document = url, term = word, value = n)

set.seed(123)
lda4 <- LDA(dtm, k = 4, control = list(seed = 123))

topics_beta <- tidy(lda4, matrix = "beta")

top_terms <- topics_beta|>
  group_by(topic)|>
  slice_max(beta, n = 14)|>
  ungroup()|>
  arrange(topic, -beta)

top_terms

#creating my color scheme for the project
military_4 <- c(
  "Command Olive"   = "#6B8E23",
  "Desert Gold"    = "#D4A017",
  "Tactical Teal" = "#1FA4A9",
  "Signal Crimson"   = "#B23A2E"
)

#Faceted graph of topics and their top terms by beta value
top_terms|>
  mutate(
    topic = factor(topic),
    term  = reorder_within(term, beta, topic)
  ) %>%
  ggplot(aes(term, beta, fill = topic)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free") +
  coord_flip() +
  scale_x_reordered() +
  scale_fill_manual(values = setNames(military_4, levels(factor(top_terms$topic)))) +
  theme_minimal() +
  labs(y = "β", x = "Terms", title = "Figure 1: Topic by Most Dominant Terms")

#now assigning each article its main topic
doc_topics <- tidy(lda4, matrix = "gamma")|>
  group_by(document)|>
  slice_max(gamma, n = 1)|>
  ungroup()|>
  rename(url = document, topic = topic)

sputnik_articles <- sputnik_articles|>
  left_join(doc_topics, by="url")

#assigning names to topics
topic_labels <- tibble::tibble(
  topic = 1:4,   # adjust if you have more topics
  topic_name = c("Economic Confrontation", "Global Partnerships", "Political Confrontation", "Special Military Operation")
)

sputnik_articles <- sputnik_articles|>
  left_join(topic_labels, by = "topic")

#bar plot of all topics' frequencies
topic_freq <- sputnik_articles|>
  count(topic_name)

ggplot(topic_freq, aes(x = reorder(topic_name, n), y = n, fill = topic_name)) +
  geom_col() +
  coord_flip() +
  scale_fill_manual(values = setNames(military_4, levels(factor(topic_freq$topic_name)))) +
  theme_bw() +
  labs(y = "Number of Articles", x = "Topic", title = "Figure 2: Topics by Number of Articles") +
  theme(legend.position = "none")

#Line plot Monthly Share of Sputnik Articles by Topic
topic_month_counts <- sputnik_articles|>
  filter(!is.na(articledate), !is.na(topic_name))|>
  mutate(month = floor_date(articledate, "month"))|>
  group_by(month, topic_name)|>
  summarise(
    n_articles = n(),
    .groups = "drop"
  )
topic_month_pcts <- topic_month_counts|>
  group_by(month)|>
  mutate(
    total_articles = sum(n_articles),
    pct_articles  = (n_articles / total_articles) * 100
  )|>
  ungroup()
ggplot(topic_month_pcts,
       aes(x = month, y = pct_articles, color = topic_name)) +
  geom_line(linewidth = 0.9) +
  theme_minimal() +
  labs(
    title = "Figure 3: Monthly Share of Sputnik Articles by Topic",
    x = "Month",
    y = "Percentage of Articles",
    color = "Topic"
  ) +
  scale_color_manual(values = setNames(military_4, levels(factor(topic_month_pcts$topic_name)))) +
  scale_x_date(date_labels = "%b '%y", date_breaks = "6 month")


#Lexicoder Sentiment Dictionary
corp <- corpus(
  sputnik_articles,
  text_field = "text_all"
)
toks <- tokens(
  corp,
  remove_punct   = TRUE,
  remove_numbers = TRUE
) %>%
  tokens_tolower()
toks <- tokens_remove(
  toks,
  pattern = c(stopwords("en"), my_stopwords$word)
)
dfm_lsd <- dfm(toks)|>
  dfm_lookup(data_dictionary_LSD2015)
lsd_scores <- convert(dfm_lsd, to = "data.frame")|>
  as_tibble()|>
  mutate(
    net_sentiment = positive - negative,
    neg_prop = negative / (positive + negative + 1),
    neg_pct  = neg_prop * 100
  )
sputnik_articles <- sputnik_articles|>
  mutate(doc_id = docnames(corp))|>
  left_join(lsd_scores, by = "doc_id")

#bar plot of topic neg_prop averages
topic_neg <- sputnik_articles|>
  group_by(topic_name)|>
  summarise(
    avg_neg_prop = mean(neg_prop, na.rm = TRUE),
    .groups = "drop"
  )|>
  mutate(avg_neg_pct = avg_neg_prop * 100)


ggplot(topic_neg, aes(x = reorder(topic_name, avg_neg_pct), y = avg_neg_pct, fill = topic_name)) +
  geom_col(show.legend = FALSE) +
  coord_flip() +
  scale_fill_manual(values = setNames(military_4, levels(factor(topic_neg$topic_name)))) +
  theme_minimal() +
  labs(
    title = "Figure 4: Negativity by Topic",
    x = "Topic",
    y = "Average Percentage of Negative Words",
    caption = "Sentiment scores are derived using the Lexicoder Sentiment Dictionary (Young & Soroka, 2012)."
  )

#Line plot
topic_month <- sputnik_articles|>
  filter(!is.na(articledate), !is.na(topic_name), !is.na(neg_pct))|>
  mutate(month = floor_date(articledate, unit = "month"))|>
  group_by(month, topic_name)|>
  summarise(
    avg_neg_pct = mean(neg_pct, na.rm = TRUE),
    n_articles  = n(),
    .groups = "drop"
  )
ggplot(topic_month, aes(x = month, y = avg_neg_pct, color = topic_name)) +
  geom_line(linewidth = 0.9) +
  scale_color_manual(
    values = setNames(military_4, levels(factor(topic_month$topic_name)))
  ) +
  theme_minimal() +
  labs(
    title = "Figure 5: Monthly Average Negativity by Topic",
    x = "Month",
    y = "Average % Negative Words",
    color = "Topic",
    caption = "Sentiment scores are derived using the Lexicoder Sentiment Dictionary (Young & Soroka, 2012)."
  ) +
  scale_x_date(date_labels = "%b '%y", date_breaks = "6 month")