

# Mostly generic string wranglers -----------------------------------------

chpt_extract_exercise_type <- function(.lines) {
  .lines %>%
    str_extract("^type: .*$") %>%
    str_remove("type: ") %>%
    str_trim()
}

chpt_extract_exercise_sections <- function(.lines) {
  .lines %>%
    # Don't want to include this in the sections
    str_remove("^`@instructions`.*$") %>%
    str_extract("`\\@.*`.*$") %>%
    str_remove_all("(^`)|(\\@)|(`$)") %>%
    str_trim()
}

chpt_extract_exercise_name <- function(.lines) {
  .lines %>%
    str_extract("## .*$") %>%
    str_remove("## ") %>%
    str_remove_all(",|\\?|\\!|\\.|\\:|\\;") %>%
    str_to_lower() %>%
    str_replace_all(" ", "-")
}

chpt_remove_extraneous_lines <- function(.lines) {
  .lines %>%
    str_remove("^(key|xp|lang|skills):.*$") %>%
    str_remove("^type: .*$") %>%
    str_remove("^`+yaml.*$") %>%
    str_remove("^`\\@.*`.*$")
}

# Separators that are surrounded by empty lines
chpt_remove_extra_separators <- function(.lines) {
  if_else(
    grepl("^$", lag(.lines)) & grepl("^$", lead(.lines)) &
      grepl("^---$", .lines),
    "",
    .lines
  )
}

# Backticks that are surrounded by empty lines
chpt_remove_extra_backticks <- function(.lines) {
  if_else(
    grepl("^$", lag(.lines)) & grepl("^$", lead(.lines)) &
      grepl("^```$", .lines, perl = TRUE),
    "",
    .lines
  )
}

chpt_modify_instruction_name <- function(.lines) {
  pattern <- "^`@instructions`.*$"
  instruction_locations <- str_which(.lines, pattern) + 1

  if (length(instruction_locations) != 0)
    .lines <- R.utils::insert(.lines, instruction_locations, "")

  .lines %>%
    str_replace(pattern, "**Instructions**:")
}

chpt_modify_dataset_path <- function(.lines) {
  .lines %>%
    str_replace("^load.*?http.*(datasets)/.*/(.*\\.[rR]da).*$", "load('\\1/\\2')") %>%
    str_replace("readRDS.*?http.*(datasets)/.*/(.*\\.[rR]ds).*$", "readRDS('\\1/\\2')") %>%
    str_replace("datasets", "www")
}

chpt_modify_yaml <- function(.lines) {
  .lines %>%
    str_remove("^free_preview: true$")
}

chpt_prep_exercise_text <- function(.lines) {
  tibble(Lines = .lines) %>%
    mutate(
      Sections = chpt_extract_exercise_sections(.data$Lines),
      ExerciseName = chpt_extract_exercise_name(.data$Lines),
      ExerciseType = chpt_extract_exercise_type(.data$Lines)
    ) %>%
    tidyr::fill("Sections", "ExerciseName", "ExerciseType") %>%
    mutate(ExerciseTag = str_c(.data$ExerciseName, "-", .data$ExerciseType))
}

# Parsing MCQ text --------------------------------------------------------

chpt_extract_mcq_text <- function(.lines) {
  mcq_text <- .lines %>%
    chpt_prep_exercise_text() %>%
    mutate(
      MCQResponses = if_else(
        .data$ExerciseType == "MultipleChoiceExercise" &
          .data$Sections == "possible_answers",
        .data$Lines,
        NA_character_
      ) %>%
        str_extract("^- .*$") %>%
        str_remove("^- "),
      MCQAnswerCheck = if_else(
        .data$ExerciseType == "MultipleChoiceExercise" &
          .data$Sections == "sct",
        .data$Lines,
        NA_character_
      ),
      MCQCorrectResponse = .data$MCQAnswerCheck %>%
        str_extract("^.*check_mc\\(.*$") %>%
        str_replace("^.*check_mc\\(([1-9]),.*$", "\\1"),
      MCQMessages = .data$MCQAnswerCheck %>%
        str_extract("^msg.*$") %>%
        str_remove('^msg.* \\"') %>%
        str_remove('\\"'),
      TabMCQResponses = NA
      )

  mcq_inside_tab <- any(str_detect(mcq_text$MCQResponses, "^\\[.*\\]$"),
                        na.rm = TRUE)
  if (mcq_inside_tab) {
    mcq_text <- mcq_text %>%
      mutate(
        TabMCQResponses = .data$MCQResponses
      )
  }

  mcq_text
}

chpt_extract_mcq_responses <- function(.lines) {
  responses <- .lines %>%
    chpt_extract_mcq_text()

  if (any(!is.na(responses$TabMCQResponses))) {
    responses <- responses %>%
      pull("TabMCQResponses")
  } else {
    responses <- responses %>%
      pull("MCQResponses")
  }

  responses %>%
    stringi::stri_remove_empty_na()
}

chpt_extract_mcq_answer <- function(.lines) {
  answer <- .lines %>%
    chpt_extract_mcq_text()

  if (any(!is.na(answer$TabMCQResponses))) {
    answer <- answer %>%
      pull("TabMCQResponses") %>%
      stringi::stri_remove_empty_na() %>%
      str_which("^\\[.*\\]$")
  } else {
    answer <- answer %>%
      pull("MCQCorrectResponse")
  }

  answer %>%
    stringi::stri_remove_empty_na()
}

chpt_extract_mcq_messages <- function(.lines) {
  msgs <- .lines %>%
    chpt_extract_mcq_text()

  if (any(!is.na(msgs$TabMCQResponses))) {
    msgs <- "FIXME"
  } else {
    msgs <- msgs %>%
      pull("MCQMessages") %>%
      stringi::stri_remove_empty_na()
  }

  msgs
}

chpt_remove_mcq_text <- function(.lines) {
  .lines %>%
    chpt_prep_exercise_text() %>%
    filter(!(
      .data$ExerciseType == "MultipleChoiceExercise" &
        .data$Sections %in% c("pre_exercise_code", "possible_answers", "sct") &
        !is.na(.data$Sections)
    )) %>%
    pull("Lines")
}

# Convert exercises to list and back --------------------------------------

chpt_exercise_to_list <- function(.lines) {
  .lines %>%
    str_flatten("\n") %>%
    str_split("\\n---\\n") %>%
    unlist() %>%
    purrr::map(str_split, pattern = "\n") %>%
    unlist(recursive = FALSE)
}

chpt_exercise_to_vector <- function(.lines) {
  .lines %>%
    unlist()
}


# Insert slides into chapter ----------------------------------------------

chpt_extract_projector_key <- function(.lines) {
  projector_key_location <- str_which(.lines, "^`@projector_key`")
  .lines[projector_key_location + 1]
}

chpt_insert_slides_text <- function(.lines, .slide_files) {
  keys <- .lines %>%
    chpt_extract_projector_key()

  slide_keys <- purrr::map_chr(.slide_files, sld_extract_key)

  for (key in keys) {
    location <- str_which(.lines, key)
    slide_file <- .slide_files[str_which(slide_keys, key)]
    if (length(slide_file) != 0) {
      slide_file <- fs::path_ext_set(slide_file, ".Rmd") %>%
        fs::path_file()
      slide_file <- fs::path("slides", slide_file)
      child_chunk <-
        c(as.character(glue::glue("```{{r, child='{slide_file}'}}")),
          "```")
      .lines <- append(.lines, child_chunk, after = location)
      .lines <- .lines %>%
        str_remove(key)
    } else {
      .lines <- .lines
    }
  }

  .lines
}

# Conversion to learnr format ---------------------------------------------

lrnr_append_yaml_output <- function(.lines_list) {
  yaml_output_lrnr <- c("output:",
                        " learnr::tutorial:",
                        "   theme: sandstone",
                        "runtime: shiny_prerendered",
                        "---")

  .lines_list[[1]] <- append(.lines_list[[1]], yaml_output_lrnr)
  .lines_list
}

lrnr_append_todo_list <- function(.lines_list) {
  todo_list <- c(
    "",
    "<!-- TODO: Deal with previous `@sct` tags (now `-check` labels), they aren't supported. -->",
    "<!-- TODO: Check that video content has been added. -->",
    "<!-- TODO: Confirm MCQ exercise has been correctly parsed. -->",
    "<!-- TODO: Check that Tab or Bullet Exercises were converted properly. -->",
    "<!-- TODO: Fix Tab or Bullet Exercise chunk labels, there will be duplicates. They need to follow the pattern as described in https://rstudio.github.io/learnr/exercises.html#hints_and_solutions -->",
    "<!-- TODO: Decide what to do with pre-exercise code from MCQ, they aren't supported. -->",
    "<!-- TODO: Decide what to do with `success_msg`, these aren't supported. -->",
    "<!-- TODO: Hint text needs to be moved to below the sample code chunk. -->",
    ""
  )

  .lines_list[[2]] <- append(.lines_list[[2]], todo_list, after = 1)
  .lines_list
}

lrnr_append_code_preamble <- function(.lines_list) {
  code_preamble <- c(
    "",
    "```{r setup, include=FALSE}",
    "library(learnr)",
    "knitr::opts_chunk$set(echo = FALSE, warning = FALSE, message = FALSE)",
    "```"
  )

  .lines_list[[2]] <- append(.lines_list[[2]], code_preamble, after = 1)
  .lines_list
}

lrnr_convert_mcq_exercises <- function(.lines_list) {
  purrr::map(
    .lines_list,
    ~ {
      mcq_responses <- tibble(
        responses = chpt_extract_mcq_responses(.x),
        messages = chpt_extract_mcq_messages(.x)
      ) %>%
        mutate(
        correct_response = seq_along(length(.data$responses)) == chpt_extract_mcq_answer(.x),
        converted = as.character(
          glue::glue(
            '  answer("{responses}", correct = {correct_response}, message = "{messages}"),'
          )
        )
      ) %>%
        pull("converted")

      exercise_tag <- str_c(
        chpt_extract_exercise_name(.x) %>%
          stringi::stri_remove_empty_na(),
        "-",
        chpt_extract_exercise_type(.x) %>%
          stringi::stri_remove_empty_na()
      )

      mcq_chunk <- ""
      if (length(mcq_responses) > 0) {
        chunk_tag <- glue::glue('```{{r {exercise_tag}-mcq, echo=FALSE}}') %>%
          as.character() %>%
          str_subset("^.*MultipleChoiceExercise-mcq.*$")

        mcq_chunk <- c(
          '',
          chunk_tag,
          '# TODO: Add the question below in the quotation marks',
          'question("",',
          mcq_responses,
          '  allow_retry = TRUE',
          ')',
          '```',
          ''
        )
      }

      mcq_locations <- str_which(.x, "^`@possible\\_answers`$")

      if (length(mcq_locations) > 1) {
        warning("There are more than one MCQ in this exercise ",
                "(is it a Tab or Bullet exercise?). Leaving MCQ text as is.")
        .lines <- .x
      } else if (length(mcq_locations) == 0) {
        .lines <- .x
      } else {
        .lines <- .x %>%
          chpt_remove_mcq_text() %>%
          append(mcq_chunk)
      }

      .lines
    }
  )
}

lrnr_convert_hint <- function(.lines_list) {
  purrr::map(
    .lines_list,
    ~ {
      .x %>%
        chpt_prep_exercise_text() %>%
        mutate_at("Lines", ~ {
          case_when(
            str_detect(.data$Lines, "^`\\@hint`") ~ as.character(glue::glue('```{{r {ExerciseTag}-hint-1, eval=FALSE}}')),
            !is.na(.data$Sections) &
              .data$Sections == "hint" &
              (lead(.data$Sections) != "hint" |
                 grepl("^```\\{r .*", lead(.data$Lines))) ~ str_c(.data$Lines, "```"),
            .data$Sections == "hint" & str_detect(.data$Lines, "^- .*$") ~
              str_replace(.data$Lines, "^- (.*)$", '"\\1"'),
            TRUE ~ .data$Lines
          )
        }) %>%
        pull("Lines")
    })
}

lrnr_convert_code_exercises <- function(.lines_list) {
  purrr::map(
    .lines_list,
    ~ {
      .x %>%
        chpt_prep_exercise_text() %>%
        filter(!(grepl("(Tab|Bullet)Exercise", .data$ExerciseType) &
                  .data$Sections == "sample_code" &
                   !is.na(.data$Sections)
                  )) %>%
        mutate_at("ExerciseTag",
                  ~ str_replace(., "(Tab|Bullet)Exercise",
                                "NormalExercise")) %>%
        mutate_at("Lines", ~ {
          case_when(
            !str_detect(.data$Lines, "```\\{r") ~ .data$Lines,
            .data$Sections == "pre_exercise_code" ~ as.character(glue::glue("```{{r {ExerciseTag}-setup}}")),
            .data$Sections == "sample_code" ~ as.character(
              glue::glue(
                "```{{r {ExerciseTag}, exercise=TRUE, exercise.setup='{ExerciseTag}-setup'}}"
              )
            ),
            .data$Sections == "solution" ~ as.character(glue::glue("```{{r {ExerciseTag}-hint-2, eval=FALSE}}")),
            .data$Sections == "sct" ~ as.character(glue::glue("```{{r {ExerciseTag}-check, eval=FALSE}}")),
            TRUE ~ .data$Lines
          )
        }) %>%
        pull("Lines") %>%
        # TODO: Not really sure what to do about the success messages...
        str_replace("^success\\_msg\\((.*)\\)$", "\\1") %>%
        # For the tab exercises. Will need to check to see how they work.
        str_replace("\\*\\*\\*", "### Exercise")
    })
}

lrnr_tidy_chapter <- function(.lines_list) {
  purrr::map(
    .lines_list,
    ~ .x %>%
      chpt_modify_yaml() %>%
      chpt_modify_dataset_path() %>%
      chpt_modify_instruction_name() %>%
      chpt_remove_extraneous_lines() %>%
      chpt_remove_extra_separators() %>%
      chpt_remove_extra_backticks()
  )
}


dc_chapter_to_lrnr_tutorial <- function(.chapter_md, .slide_files = NULL) {
  .lines <- readr::read_lines(.chapter_md)

  if (!is.null(.slide_files)) {
    .lines <- .lines %>%
      chpt_insert_slides_text(.slide_files = .slide_files)
  }

  .lines %>%
    chpt_exercise_to_list() %>%
    lrnr_convert_mcq_exercises() %>%
    lrnr_convert_code_exercises() %>%
    lrnr_convert_hint() %>%
    lrnr_append_yaml_output() %>%
    lrnr_append_code_preamble() %>%
    lrnr_append_todo_list() %>%
    lrnr_tidy_chapter() %>%
    chpt_exercise_to_vector() %>%
    util_remove_repeated_empty_lines()
}
