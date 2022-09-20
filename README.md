# VBIC
R code for the VBIC document classification algorithm

## About the algorithm
TBD

## Vignette
In this example, I will describe how to use the `vbic_classfiy()` function to map NIH grants about COVID-19 to the goals and objectives outlined in the NIH Strategic Plan for COVID-19. 
The first step in the process is to obtain the document set to be categorized. We will use the `get_nih_reporter()` R functions to obtain the grants from the NIH RePORTER API, so we first load these functions with `source()`. 
```r
source(“get_nih_reporter.r”)
```
Then we define the search query and run it to download the relevant document set. 
```r
covid_q <- create_query(covid_response = c("Reg-CV", "CV", "C3", "C4", "C5", "C6"))
grants <- get_nih_reporter(covid_q, outfile = “nih_covid_grants.txt”)
```
Next, we create a document text column that combines each grant’s title, abstract, and public health relevance texts into a single text field for analysis and transform the document text to lowercase to improve matching accuracy. Notice that the grant’s project title is listed three times in this example to increase the weight of terms appearing in the title in the final concept scores.
```r
grants$doc_text <- paste(grants$project_title, grants$abstract_text, grants$phr_text, grants$project_title, grants$project_title, sep = “. “)
grants$doc_text <- tolower(grants$doc_text)
```
The next step is to load the `vbic_classify()` function and the term vocabulary to be used to classify the documents. 
```r
source(“vbic_classify.r”)
term_vocab <- read.csv(“nih_covid_terms_exp.csv”, stringsAsFactors = FALSE, allowEscapes = TRUE)
```
In the NIH Strategic Plan for COVID-19, priorities 1-4 are scientific topic areas, whereas priority 5 defines a set of high-risk population groups. In this classification, each grant should belong to one or more of priorities 1-4, but should only belong to priority 5 if the grant is about one or more of those groups. To do so, we will split the original term list into two lists and run each through the `vbic_classify()` function separately with different values for the “unclassified” argument. 
First, we define two new vocabulary lists – “them” and “pop” – for themes 1-4 and objective 5, respectively. 
```r
them <- term_vocab[term_vocab$priority != 5,]
pop <- term_vocab[term_vocab$priority == 5,]
```
Then we run each through the `vbic_classify()` function to create document-concept matrices and concept assignments for them. Notice in the second function call that we set `unclassified = TRUE` to ensure that documents are only assigned one or more of the concepts in the “pop” vocabulary if their concept scores for those concepts are greater than or equal to the specified concept threshold of 20. In the first function call, however, we use the default value of FALSE for this argument to assign documents to their highest concept score regardless of whether they meet the threshold.  
```r
them_out <- vbic_classify(grants, them, doc_id_column = “appl_id”, doc_text_column = “doc_text”, concept_threshold = 20, term_concept_column = “subtheme”)
pop_out <- vbic_classify(grants, pop, doc_id_column = “appl_id”, doc_text_column = “doc_text”, concept_threshold = 20, unclassified = TRUE, term_concept_column = “subtheme”)
```
Each function call returns a list object containing two data frames: the original document-concept matrix (“$dcm”) and the summarized concept list (“$concept_list”). So the final step is to combine the concept lists for each run into a single data frame, clean up the resulting columns and column names, and then merge the document classifications back into the original grant data. 
```r
concept_sum <- merge(them_out$concept_list, pop_out$concept_list, by = "doc_id")
concept_sum$doc_text.y = NULL
colnames(concept_sum) <- c("doc_id", "doc_text", "primary_theme", "all_themes", "primary_pop", "all_pops", "highest_score")
concept_sum$primary_pop <- NULL
concept_sum$all_themes_pops <- paste(concept_sum$all_themes, concept_sum$all_pops, sep = ";")
concept_sum$all_themes_pops <- gsub(";unclassified", "", concept_sum$all_themes_pops)
concept_sum$highest_score <- NULL
grants2 <- merge(grants, concept_sum, by.x = "appl_id", by.y = "doc_id")
```
The resulting `grants2` data frame now has a set of columns for the derived document classifications that we can now use in additional analyses. 
