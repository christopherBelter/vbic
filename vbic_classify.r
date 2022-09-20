## version 0.35

vbic_classify <- function(doc_csv, term_csv, concept_threshold = 20, unclassified = FALSE, doc_id_column = "", doc_text_column = "", term_name_column = "term", term_concept_column = "concept", term_weight_column = "weight") {

## need to specify: term DF, term DF column names, doc DF, doc ID column name, doc title column, doc text columns
## could create preset lists of document columns based on document source: reporter, qvr, pubmed, wos, scopus, etc
## *** update: preset lists do too much; doesn't allow the user to define other text columns from data sources

## use allowEscapes = TRUE in read.csv to get backslashes to read in correctly (i.e. \\ in the file stays \\ instead of being changed to \\\\
#term_csv$term <- gsub("\\\\b", "\\b", term_csv[,term_name_column])
termLists <- split(term_csv[,term_name_column], term_csv[,term_concept_column])
termWeights <- split(term_csv[,term_weight_column], term_csv[,term_concept_column])
termLists <- lapply(1:length(termLists), function(x) rep(termLists[[x]], termWeights[[x]]))
names(termLists) <- names(termWeights)

## set up the text for generating the document-concept matrix
doc_concept_matrix <- data.frame(doc_id = doc_csv[,doc_id_column], doc_text = doc_csv[,doc_text_column])
doc_concept_matrix$doc_text <- tolower(doc_concept_matrix$doc_text)

## generate concept scores for each document for each concept and rename the resulting columns
for (i in 1:length(termLists)) {
  doc_concept_matrix[,i + 2] <- sapply(1:nrow(doc_concept_matrix), function(x) sum(stringr::str_count(doc_concept_matrix$doc_text[x], termLists[[i]])))
  message(paste("Finished term list", i, "of", length(termLists)))
}
colnames(doc_concept_matrix) <- c("doc_id", "doc_text", names(termLists))

## identify the concepts in the doc_concept_matrix with concept scores above the preselected threshold
concepts <- sapply(1:nrow(doc_concept_matrix), function(x) names(doc_concept_matrix[which(doc_concept_matrix[x,] >= concept_threshold)])) 
concepts <- lapply(1:length(concepts), function(x) concepts[[x]][!concepts[[x]] %in% c("doc_id", "doc_text")])

## create a results table with the document ID, primary concept (i.e. the concept with the highest concept score), and a delimited list of the concepts above the threshold
concept_sum <- data.frame(doc_id = doc_concept_matrix$doc_id, doc_text = doc_concept_matrix$doc_text, primary_concept = sapply(1:nrow(doc_concept_matrix), function(x) paste(colnames(doc_concept_matrix)[which(doc_concept_matrix[x,3:ncol(doc_concept_matrix)] == max(doc_concept_matrix[x,3:ncol(doc_concept_matrix)])) + 2], collapse = ";")), all_concepts = sapply(concepts, paste, collapse = ";"))
concept_sum$all_concepts[concept_sum$all_concepts == ""] <- "unclassified"

if (unclassified == FALSE) {
	## create a final concept list for each document that includes the unique set of the primary and all secondary concepts
	## necessary because some documents don't have enough text to meet the threshold for any concept, so they end up being assigned to whichever concept score is highest
	fin_concepts <- sapply(1:nrow(concept_sum), function(x) unique(c(unlist(strsplit(concept_sum[x,3], ";")), unlist(strsplit(concept_sum[x,4], ";")))))
	fin_concepts <- lapply(fin_concepts, sort)
	## merge the results back into the concept_sum table
	concept_sum$all_concepts <- sapply(fin_concepts, paste, collapse = ";")
	concept_sum$all_concepts <- gsub(";unclassified", "", concept_sum$all_concepts)
	concept_sum$all_concepts <- gsub("unclassified;", "", concept_sum$all_concepts)
	## isolate docs that have no term matches in the term_csv table and set them to 'unclassified'
	concept_sum$primary_concept[sapply(1:nrow(doc_concept_matrix), function(x) sum(doc_concept_matrix[x,3:ncol(doc_concept_matrix)])) == 0] <- "unclassified"
	concept_sum$all_concepts[concept_sum$primary_concept == "unclassified"] <- "unclassified"
}
else {
	concept_sum$highest_score <- concept_sum$primary_concept
	concept_sum$primary_concept[concept_sum$all_concepts == "unclassified"] <- "unclassified"
	concept_sum$all_concepts <- gsub(";unclassified", "", concept_sum$all_concepts)
	concept_sum$all_concepts <- gsub("unclassified;", "", concept_sum$all_concepts)
}

results_list <- list(dcm = doc_concept_matrix, concept_list = concept_sum)
return(results_list)
}