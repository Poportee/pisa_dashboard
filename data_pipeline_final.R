library(dplyr)
library(haven)
library(intsvy)

path <- "C:/Users/Paul/OneDrive/Bureau/BOSSER/Mines/2A/S8/data_collection"

# 1. Configuration des répertoires temporaires
temp_dir <- tempdir()
if(!dir.exists(temp_dir)) dir.create(temp_dir)
options(haven.import.integer64 = "double")  # Éviter les problèmes avec les grands entiers

# 2. Colonnes nécessaires
cols_essential <- c("CNTSTUID", "CNT", "W_FSTUWT", 
                    paste0("PV", 1:10, "READ"), 
                    paste0("PV", 1:10, "SCIE"))

# 3. Pays européens
pays_europeens <- c("ALB", "AUT", "BEL", "BGR", "HRV", "CYP", "CZE", "DNK", "EST", "FIN", 
                    "FRA", "DEU", "GRC", "HUN", "ISL", "IRL", "ITA", "LVA", "LTU", "LUX", 
                    "MLT", "MNE", "NLD", "NOR", "POL", "PRT", "ROU", "SRB", "SVK", "SVN", 
                    "ESP", "SWE", "CHE", "GBR", "TUR")

# 4. Fonction robuste de lecture par chunks
read_pisa_chunked <- function(year, chunk_size){
  file_info <- switch(year,
                      "2022" = list(stu = "data/2022/CY08MSP_STU_QQQ.SAS7BDAT",
                                    cog = "data/2022/CY08MSP_STU_COG.SAS7BDAT"),
                      "2018" = list(stu = "data/2018/cy07_msu_stu_qqq.sas7bdat",
                                    cog = "data/2018/cy07_msu_stu_cog.sas7bdat"),
                      "2015" = list(stu = "data/2015/cy6_ms_cmb_stu_qqq.sas7bdat",
                                    cog = "data/2015/cy6_ms_cmb_stu_cog.sas7bdat"))
  
  # Vérification de l'existence des fichiers
  if(!file.exists(file.path(path, file_info$stu))) {
    stop("Fichier étudiant introuvable: ", file.path(path, file_info$stu))
  }
  if(!file.exists(file.path(path, file_info$cog))) {
    stop("Fichier cognitif introuvable: ", file.path(path, file_info$cog))
  }
  
  # Initialisation des résultats
  final_data <- NULL
  processed_ids <- character(0)
  
  # Lecture du fichier étudiant par chunks
  message("Début de la lecture chunkée pour ", year)
  
  # Création d'une connexion robuste
  stu_con <- file(file.path(path, file_info$stu), "rb")
  on.exit(close(stu_con))
  
  chunk_index <- 1
  while(TRUE) {
    message("Traitement du chunk #", chunk_index)
    
    # Lecture du chunk avec gestion d'erreur
    stu_chunk <- tryCatch({
      read_sas(stu_con, n_max = chunk_size) %>%
        select(any_of(cols_essential)) %>%
        filter(CNT %in% pays_europeens)
    }, error = function(e) {
      message("Erreur lors de la lecture: ", e$message)
      NULL
    })
    
    if(is.null(stu_chunk) break
       if(nrow(stu_chunk) == 0) break
       
       # Vérification des nouveaux IDs
       new_ids <- setdiff(stu_chunk$CNTSTUID, processed_ids)
       if(length(new_ids) == 0) {
         message("Aucun nouvel ID dans ce chunk, passage au suivant")
         chunk_index <- chunk_index + 1
         next
       }
       
       # Lecture des données cognitives correspondantes
       cog_chunk <- tryCatch({
         read_sas(file.path(path, file_info$cog)) %>%
           filter(CNTSTUID %in% new_ids) %>%
           select(any_of(cols_essential))
       }, error = function(e) {
         message("Erreur lecture cognitive: ", e$message)
         NULL
       })
       
       if(!is.null(cog_chunk)) {
         # Jointure des données
         joined_chunk <- stu_chunk %>%
           left_join(cog_chunk, by = "CNTSTUID", suffix = c("", ".cog")) %>%
           mutate(DTE = as.numeric(year))
         
         # Accumulation des résultats
         if(is.null(final_data)) {
           final_data <- joined_chunk
         } else {
           final_data <- bind_rows(final_data, joined_chunk)
         }
         
         # Mise à jour des IDs traités
         processed_ids <- unique(c(processed_ids, new_ids))
       }
       
       # Nettoyage mémoire
       rm(stu_chunk, cog_chunk, joined_chunk)
       gc()
       
       chunk_index <- chunk_index + 1
  }
  
  return(final_data)
}

# 5. Fonction de traitement par année avec gestion d'erreur
process_year_safe <- function(year, chunk_size = 30000) {
  tryCatch({
    message("\n--- Début traitement ", year, " ---")
    
    # Lecture des données
    data <- read_pisa_chunked(year, chunk_size)
    
    if(is.null(data) || nrow(data) == 0) {
      stop("Aucune donnée valide pour ", year)
    }
    
    # Calcul des scores
    scores <- calculate_pisa_scores(data, year)
    
    # Sauvegarde
    save_file <- file.path(path, paste0("pisa_temp_", year, ".rds"))
    saveRDS(list(data = data, read = scores$read, scie = scores$scie), save_file)
    
    message("--- ", year, " traité avec succès ---")
    return(TRUE)
  }, error = function(e) {
    message("ÉCHEC traitement ", year, ": ", e$message)
    return(FALSE)
  }, finally = {
    # Nettoyage
    if(exists("data")) rm(data)
    if(exists("scores")) rm(scores)
    gc()
  })
}

# 6. Exécution principale
years <- c("2022", "2018", "2015")
results <- list()

for (y in years) {
  # Ajustement dynamique de la taille des chunks
  chunk_size <- ifelse(y == "2022", 20000, 30000)
  
  # Tentative de traitement
  success <- process_year_safe(y, chunk_size)
  
  if(!success) {
    # Réessayer avec des chunks plus petits en cas d'échec
    message("Nouvelle tentative avec des chunks plus petits")
    success <- process_year_safe(y, chunk_size = 10000)
  }
  
  results[[y]] <- success
}

# 7. Combinaison des résultats réussis
combine_successful_results <- function() {
  successful_years <- names(which(unlist(results)))
  
  if(length(successful_years) == 0) {
    stop("Aucune année n'a pu être traitée avec succès")
  }
  
  all_data <- list()
  all_read <- list()
  all_scie <- list()
  
  for (y in successful_years) {
    temp <- readRDS(file.path(path, paste0("pisa_temp_", y, ".rds")))
    all_data[[y]] <- temp$data
    all_read[[y]] <- temp$read
    all_scie[[y]] <- temp$scie
  }
  
  pisa_europe_all <- bind_rows(all_data)
  pisa_avg_read <- bind_rows(all_read)
  pisa_avg_scie <- bind_rows(all_scie)
  
  # Sauvegarde finale
  saveRDS(pisa_europe_all, file.path(path, "pisa_europe_2015_2018_2022.rds"))
  saveRDS(pisa_avg_read, file.path(path, "pisa_avg_read.rds"))
  saveRDS(pisa_avg_scie, file.path(path, "pisa_avg_scie.rds"))
  
  # Export CSV
  write.csv(pisa_europe_all, file.path(path, "pisa_europe_all.csv"), row.names = FALSE)
  
  return(list(all = pisa_europe_all, read = pisa_avg_read, scie = pisa_avg_scie))
}

# Exécution finale
final_results <- combine_successful_results()
