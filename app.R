# app.R
library(shiny)
library(shinydashboard)
library(shinyFiles)
library(shinyjs)
library(DT)
library(processx)
library(jsonlite)

# UI
ui <- fluidPage(
  useShinyjs(),
  tags$head(
    tags$style(HTML("
      body { background-color: #f4f4f4; }
      .title-section {
        text-align: center;
        padding: 15px 0;
        background-color: #2c3e50;
        color: white;
      }
      .step-section {
        background-color: white;
        margin: 10px;
        padding: 15px;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      }
      .param-group {
        border: 1px solid #dee2e6;
        border-radius: 8px;
        padding: 10px;
        margin-bottom: 10px;
        background-color: #f8f9fa;
      }
      .param-group h4 {
        margin-top: 0;
        margin-bottom: 8px;
        color: #495057;
        border-bottom: 1px solid #dee2e6;
        padding-bottom: 5px;
      }
      .selected-file {
        background-color: #f8f9fa;
        border: 1px solid #dee2e6;
        border-radius: 4px;
        padding: 6px 10px;
        margin-top: 6px;
        font-family: monospace;
        font-size: 11px;
        color: #495057;
        max-height: 60px;
        overflow-y: auto;
      }
      .login-box {
        background: #f8f9fa;
        border: 1px solid #dee2e6;
        border-radius: 8px;
        padding: 15px;
        margin-bottom: 15px;
      }
      .auth-status {
        padding: 8px;
        border-radius: 4px;
        margin-bottom: 10px;
      }
      .auth-success {
        background-color: #d4edda;
        border: 1px solid #c3e6cb;
        color: #155724;
      }
      .auth-needed {
        background-color: #fff3cd;
        border: 1px solid #ffeeba;
        color: #856404;
      }
      .validation-message {
        padding: 8px;
        border-radius: 4px;
        margin: 8px 0;
      }
      .validation-success {
        background-color: #d4edda;
        border: 1px solid #c3e6cb;
        color: #155724;
      }
      .validation-error {
        background-color: #f8d7da;
        border: 1px solid #f5c6cb;
        color: #721c24;
      }
      .validation-warning {
        background-color: #fff3cd;
        border: 1px solid #ffeeba;
        color: #856404;
      }
    "))
  ),
  
  div(class = "title-section",
      h1("DeepTools Analysis Generator",
         style = "margin: 0; font-size: 48px; font-weight: 300;"),
      p("Generate heatmaps and profile plots from BigWig files using computeMatrix and plotHeatmap/plotProfile",
        style = "margin: 10px 0 0 0; font-size: 14px; opacity: 0.8;")
  ),
  
  div(class = "step-section",
      h3("Parameter Management", style = "text-align: center; margin-bottom: 20px;"),
      div(class = "param-group",
          h4("Load Saved Parameters"),
          p("Load previously saved parameters to quickly restore your configuration:"),
          fileInput("load_params", NULL,
                    accept = ".json",
                    buttonLabel = "Browse for Parameter File...",
                    placeholder = "No file selected",
                    width = "100%"),
          div(id = "load_status", style = "margin-top: 10px;")
      )
  ),
  
  div(class = "step-section",
      h3("HiPerGator File Access", style = "text-align: center; margin-bottom: 20px;"),
      uiOutput("auth_status"),
      conditionalPanel(
        condition = "!output.authenticated",
        div(class = "login-box",
            h4("Login for HiPerGator File Access"),
            p("Enter your group credentials to browse HiPerGator files:"),
            fluidRow(
              column(6, textInput("group_name", "HiperGator Group",
                                  placeholder = "e.g., cancercenter-dept",
                                  value = "cancercenter-dept")),
              column(6, passwordInput("group_password", "Password"))
            ),
            actionButton("login_btn", "Login", class = "btn-primary")
        )
      ),
      conditionalPanel(
        condition = "output.authenticated",
        div(style = "text-align: right;",
            actionButton("logout_btn", "Logout", class = "btn-secondary btn-sm")
        )
      )
  ),
  
  div(class = "step-section",
      h2("Required Parameters", style = "text-align: center; margin-bottom: 30px;"),
      div(class = "param-group",
          h4("Basic Configuration"),
          fluidRow(
            column(4, textInput("project_id", "Project ID",
                                placeholder = "RCHACV_analysis")),
            column(4, textInput("output_dir", "Output Directory",
                                placeholder = "/blue/your-group/path/to/output")),
            column(4, radioButtons("plot_type", "Plot Type:",
                                   choices = list("Heatmap" = "heatmap", "Profile" = "profile"),
                                   selected = "heatmap"))
          )
      ),
      div(class = "param-group",
          h4("Input Files"),
          h5("BigWig Files", tags$span("*", style = "color: red;")),
          p("Select multiple BigWig files for analysis:"),
          conditionalPanel(
            condition = "output.authenticated",
            textInput("custom_path_bigwig", "Directory Path:", value = "",
                      placeholder = "Enter path relative to volume..."),
            shinyFilesButton("browse_bigwig", "Browse BigWig Files",
                             "Select multiple BigWig files", class = "btn-info", multiple = TRUE),
            uiOutput("selected_bigwig_files")
          ),
          conditionalPanel(
            condition = "!output.authenticated",
            div(style = "padding: 10px; text-align: center; color: #856404; font-size: 12px;",
                tags$i(class = "fa fa-lock"), " Login above to browse HiPerGator files"
            )
          ),
          br(),
          h5("Regions File (BED format)", tags$span("*", style = "color: red;")),
          p("Select the BED file containing regions of interest:"),
          conditionalPanel(
            condition = "output.authenticated",
            textInput("custom_path_regions", "Directory Path:", value = "",
                      placeholder = "Enter path relative to volume..."),
            shinyFilesButton("browse_regions", "Browse Regions File",
                             "Select BED file", class = "btn-info", multiple = FALSE),
            uiOutput("selected_regions_file")
          ),
          conditionalPanel(
            condition = "!output.authenticated",
            div(style = "padding: 10px; text-align: center; color: #856404; font-size: 12px;",
                tags$i(class = "fa fa-lock"), " Login above to browse HiPerGator files"
            )
          )
      )
  ),
  
  div(class = "step-section",
      h2("Analysis Parameters", style = "text-align: center; margin-bottom: 30px;"),
      div(class = "param-group",
          h4("computeMatrix Parameters"),
          fluidRow(
            column(4, selectInput("reference_point", "Reference Point",
                                  choices = list("TSS" = "TSS", "TES" = "TES", "center" = "center"),
                                  selected = "TSS")),
            column(4, numericInput("before_region", "Base pairs before (-b)",
                                   value = 2000, min = 0)),
            column(4, numericInput("after_region", "Base pairs after (-a)",
                                   value = 2000, min = 0))
          ),
          fluidRow(
            column(6, numericInput("y_min", "Y-axis minimum", value = 0, step = 0.1)),
            column(6, numericInput("y_max", "Y-axis maximum", value = 1.5, step = 0.1))
          ),
          fluidRow(
            column(4,
                   numericInput("chunk_size", "Chunk size (regions per chunk)",
                                value = 5000, min = 1000, max = 20000),
                   helpText("Split large BED files into smaller chunks for faster processing")),
            column(4, checkboxInput("skip_zeros", "Skip zeros", value = TRUE)),
            column(4, checkboxInput("missing_data_as_zero", "Missing data as zero", value = TRUE))
          ),
          fluidRow(
            column(6, selectInput("processors", "Processors",
                                  choices = list("1" = "1", "2" = "2", "4" = "4", "8" = "8", "max" = "max"),
                                  selected = "max"))
          )
      ),
      
      # Conditional UI for plot-specific parameters
      conditionalPanel(
        condition = "input.plot_type == 'heatmap'",
        div(class = "param-group",
            h4("plotHeatmap Parameters"),
            fluidRow(
              column(6, numericInput("heatmap_width", "Heatmap Width",
                                     value = 6, min = 1, max = 20)),
              column(6, textInput("x_axis_label", "X-axis Label",
                                  value = "distance (bp)"))
            ),
            fluidRow(
              column(6, textInput("y_axis_label", "Y-axis Label", value = "Genes")),
              column(6, textInput("regions_label", "Regions Label", value = "ATAC"))
            ),
            fluidRow(
              column(6, textInput("color_list", "Color List (comma-separated)",
                                  value = "white,red")),
              column(6, selectInput("sort_using", "Sort Using",
                                    choices = list("mean" = "mean", "median" = "median",
                                                   "max" = "max", "min" = "min", "sum" = "sum"),
                                    selected = "mean"))
            ),
            textAreaInput("sample_labels", "Sample Labels (one per line, in order of BigWig files)",
                          placeholder = "Sample1\nSample2\nSample3", rows = 4)
        )
      ),
      
      conditionalPanel(
        condition = "input.plot_type == 'profile'",
        div(class = "param-group",
            h4("plotProfile Parameters"),
            fluidRow(
              column(6, textInput("x_axis_label_profile", "X-axis Label",
                                  value = "distance (bp)")),
              column(6, textInput("y_axis_label_profile", "Y-axis Label", value = "mean RPKM"))
            ),
            fluidRow(
              column(6, numericInput("plot_width", "Plot Width",
                                     value = 8, min = 4, max = 20)),
              column(6, numericInput("plot_height", "Plot Height",
                                     value = 6, min = 4, max = 15))
            ),
            div(
              textAreaInput("sample_groups", "Sample Grouping (sample,group,color format)",
                            placeholder = "Sample1,Group1,red\nSample2,Group1,red\nSample3,Group2,blue\nSample4,Group2,blue",
                            rows = 6),
              p("Format: one line per sample as 'SampleName,GroupName,Color'. Each group will get its own plot with all samples in that group using the specified color.",
                style = "font-size: 12px; color: #6c757d; margin-top: 5px;")
            )
        )
      )
  ),
  
  div(class = "step-section",
      h2("Computational Resources", style = "text-align: center; margin-bottom: 30px;"),
      div(class = "param-group",
          h4("SLURM Job Parameters"),
          fluidRow(
            column(4, numericInput("sbatch_cpus", "CPUs", value = 8, min = 1, max = 32)),
            column(4, textInput("sbatch_memory", "Memory", value = "32G")),
            column(4, textInput("sbatch_time", "Time Limit", value = "4:00:00"))
          ),
          fluidRow(
            column(4, textInput("sbatch_partition", "Partition", value = "hpg-default")),
            column(4, textInput("sbatch_account", "Account",
                                placeholder = "your-group", value = "")),
            column(4, checkboxInput("use_burst", "Use burst QoS (-b)", value = FALSE))
          ),
          textInput("user_email", "Email for notifications",
                    placeholder = "your.email@ufl.edu")
      )
  ),
  
  div(class = "step-section",
      h2("Generate and Run Analysis", style = "text-align: center; margin-bottom: 30px;"),
      div(style = "text-align: center;",
          actionButton("validate_params", "Validate Parameters", class = "btn-secondary btn-lg"),
          br(), br(),
          actionButton("run_analysis", "Run Analysis", class = "btn-success btn-lg", disabled = TRUE),
          br(), br(),
          downloadButton("download_script", "Download Script", class = "btn-info btn-lg", disabled = TRUE),
          br(), br(),
          downloadButton("save_params", "Save Parameters", class = "btn-warning btn-lg")
      ),
      br(),
      uiOutput("validation_status"),
      br(),
      verbatimTextOutput("script_preview"),
      br(),
      uiOutput("analysis_status"),
      br(),
      uiOutput("output_files")
  )
)

server <- function(input, output, session) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
  
  values <- reactiveValues(
    authenticated = FALSE,
    volume_root = NULL,
    selected_bigwig_files = NULL,
    selected_regions_file = NULL,
    analysis_running = FALSE,
    process = NULL,
    output_dir = NULL
  )
  
  observeEvent(input$login_btn, {
    if(input$group_name != "" && input$group_password != "") {
      volume_root <- paste0("/blue/", input$group_name)
      if(dir.exists(volume_root)) {
        values$authenticated <- TRUE
        values$volume_root <- volume_root
        shinyFileChoose(input, "browse_bigwig",
                        roots = setNames(volume_root, input$group_name),
                        filetypes = c("bw", "bigwig"))
        shinyFileChoose(input, "browse_regions",
                        roots = setNames(volume_root, input$group_name),
                        filetypes = c("bed", "txt", "csv"))
        showNotification("Successfully authenticated!", type = "message")
      } else {
        showNotification("Authentication failed or directory not accessible!", type = "error")
      }
    }
  })
  
  observeEvent(input$logout_btn, {
    values$authenticated <- FALSE
    values$volume_root <- NULL
    values$selected_bigwig_files <- NULL
    values$selected_regions_file <- NULL
  })
  
  output$authenticated <- reactive({
    values$authenticated
  })
  outputOptions(output, "authenticated", suspendWhenHidden = FALSE)
  
  output$auth_status <- renderUI({
    if(values$authenticated) {
      div(class = "auth-status auth-success",
          tags$i(class = "fa fa-check-circle"),
          " Authenticated for group:", strong(input$group_name))
    } else {
      div(class = "auth-status auth-needed",
          tags$i(class = "fa fa-exclamation-circle"),
          " Please login to browse HiPerGator files")
    }
  })
  
  observeEvent(input$browse_bigwig, {
    if(!is.null(input$browse_bigwig)) {
      files <- parseFilePaths(setNames(values$volume_root, input$group_name), input$browse_bigwig)
      if(nrow(files) > 0) {
        values$selected_bigwig_files <- as.character(files$datapath)
      }
    }
  })
  
  observeEvent(input$browse_regions, {
    if(!is.null(input$browse_regions)) {
      files <- parseFilePaths(setNames(values$volume_root, input$group_name), input$browse_regions)
      if(nrow(files) > 0) {
        values$selected_regions_file <- as.character(files$datapath)
      }
    }
  })
  
  # Observer for custom BigWig path
  observeEvent(input$custom_path_bigwig, {
    if(values$authenticated && input$custom_path_bigwig != "") {
      custom_root <- file.path(values$volume_root, input$custom_path_bigwig)
      if(dir.exists(custom_root)) {
        shinyFileChoose(input, "browse_bigwig",
                        roots = setNames(custom_root, basename(custom_root)),
                        filetypes = c("bw", "bigwig"))
      } else {
        showNotification("Custom path does not exist!", type = "warning")
        # Reset to volume root
        shinyFileChoose(input, "browse_bigwig",
                        roots = setNames(values$volume_root, input$group_name),
                        filetypes = c("bw", "bigwig"))
      }
    }
  })
  
  # Observer for custom regions path
  observeEvent(input$custom_path_regions, {
    if(values$authenticated && input$custom_path_regions != "") {
      custom_root <- file.path(values$volume_root, input$custom_path_regions)
      if(dir.exists(custom_root)) {
        shinyFileChoose(input, "browse_regions",
                        roots = setNames(custom_root, basename(custom_root)),
                        filetypes = c("bed", "txt", "csv"))
      } else {
        showNotification("Custom path does not exist!", type = "warning")
        # Reset to volume root
        shinyFileChoose(input, "browse_regions",
                        roots = setNames(values$volume_root, input$group_name),
                        filetypes = c("bed", "txt", "csv"))
      }
    }
  })
  
  output$selected_bigwig_files <- renderUI({
    if(!is.null(values$selected_bigwig_files) && length(values$selected_bigwig_files) > 0) {
      div(
        h6(paste("Selected", length(values$selected_bigwig_files), "BigWig files:")),
        div(class = "selected-file",
            paste(basename(values$selected_bigwig_files), collapse = "\n"))
      )
    }
  })
  
  output$selected_regions_file <- renderUI({
    if(!is.null(values$selected_regions_file)) {
      div(
        h6("Selected regions file:"),
        div(class = "selected-file", basename(values$selected_regions_file))
      )
    }
  })
  
  observe({
    if(values$authenticated && input$sbatch_account == "") {
      updateTextInput(session, "sbatch_account", value = input$group_name)
    }
  })
  
  observeEvent(input$validate_params, {
    errors <- c()
    warnings <- c()
    
    if(is.null(values$selected_bigwig_files) || length(values$selected_bigwig_files) == 0) {
      errors <- c(errors, "No BigWig files selected")
    }
    
    if(is.null(values$selected_regions_file)) {
      errors <- c(errors, "No regions file selected")
    }
    
    if(input$project_id == "" || is.null(input$project_id)) {
      errors <- c(errors, "Project ID is required")
    }
    
    if(input$output_dir == "" || is.null(input$output_dir)) {
      errors <- c(errors, "Output directory is required")
    }
    
    # Always require sbatch parameters now
    if(input$sbatch_account == "" || is.null(input$sbatch_account)) {
      errors <- c(errors, "Account is required for SLURM submission")
    }
    if(input$user_email == "" || is.null(input$user_email)) {
      warnings <- c(warnings, "Email is recommended for job notifications")
    }
    
    # Validate plot-specific parameters
    if(input$plot_type == "heatmap") {
      if(input$sample_labels != "") {
        labels <- trimws(unlist(strsplit(input$sample_labels, "\n")))
        labels <- labels[labels != ""]
        if(length(labels) != length(values$selected_bigwig_files)) {
          warnings <- c(warnings, paste("Number of sample labels (", length(labels),
                                        ") doesn't match number of BigWig files (",
                                        length(values$selected_bigwig_files), ")"))
        }
      }
    } else if(input$plot_type == "profile") {
      if(input$sample_groups == "" || is.null(input$sample_groups)) {
        errors <- c(errors, "Sample grouping is required for profile plots")
      } else {
        # Validate sample grouping format
        group_lines <- trimws(unlist(strsplit(input$sample_groups, "\n")))
        group_lines <- group_lines[group_lines != ""]
        
        valid_format <- TRUE
        sample_names <- c()
        for(line in group_lines) {
          parts <- trimws(unlist(strsplit(line, ",")))
          if(length(parts) != 3) {
            valid_format <- FALSE
            break
          }
          sample_names <- c(sample_names, parts[1])
        }
        
        if(!valid_format) {
          errors <- c(errors, "Sample grouping must be in format: SampleName,GroupName,Color (one per line)")
        } else if(length(sample_names) != length(values$selected_bigwig_files)) {
          errors <- c(errors, paste("Number of samples in grouping (", length(sample_names),
                                    ") doesn't match number of BigWig files (",
                                    length(values$selected_bigwig_files), ")"))
        }
      }
    }
    
    if(length(errors) == 0) {
      shinyjs::enable("run_analysis")
      shinyjs::enable("download_script")
      shinyjs::enable("save_params")
    } else {
      shinyjs::disable("run_analysis")
      shinyjs::disable("download_script")
      shinyjs::disable("save_params")
    }
    
    output$validation_status <- renderUI({
      if(length(errors) > 0) {
        div(class = "validation-message validation-error",
            tags$strong("Errors:"),
            tags$ul(lapply(errors, tags$li)))
      } else if(length(warnings) > 0) {
        div(class = "validation-message validation-warning",
            tags$strong("Warnings:"),
            tags$ul(lapply(warnings, tags$li)))
      } else {
        div(class = "validation-message validation-success",
            tags$i(class = "fa fa-check"), " All parameters validated successfully!")
      }
    })
  })
  
  generate_script_from_template <- function(template_file) {
    if(!file.exists(template_file)) {
      return("Error: Template file not found")
    }
    
    template_content <- readLines(template_file)
    
    # Generate sample labels or groups based on plot type
    if(input$plot_type == "heatmap") {
      sample_labels_str <- ""
      if(input$sample_labels != "") {
        labels <- trimws(unlist(strsplit(input$sample_labels, "\n")))
        labels <- labels[labels != ""]
        if(length(labels) == length(values$selected_bigwig_files)) {
          sample_labels_str <- paste0('"', paste(labels, collapse = '" "'), '"')
        } else {
          sample_labels_str <- paste0('"', paste(basename(values$selected_bigwig_files), collapse = '" "'), '"')
        }
      } else {
        sample_labels_str <- paste0('"', paste(basename(values$selected_bigwig_files), collapse = '" "'), '"')
      }
    } else {
      # For profile plots, we need to process the grouping
      group_lines <- trimws(unlist(strsplit(input$sample_groups, "\n")))
      group_lines <- group_lines[group_lines != ""]
      sample_labels_str <- paste0('"', paste(sapply(group_lines, function(x) unlist(strsplit(x, ","))[1]), collapse = '" "'), '"')
    }
    
    skip_zeros_param <- ifelse(input$skip_zeros, "--skipZeros", "")
    missing_data_param <- ifelse(input$missing_data_as_zero, "--missingDataAsZero", "")
    
    # Handle QoS line
    qos_line <- ""
    if(input$use_burst && input$sbatch_account != "") {
      qos_line <- paste0("#SBATCH --qos=", input$sbatch_account, "-b")
    }
    
    # Handle email lines  
    email_lines <- ""
    if(input$user_email != "") {
      email_lines <- paste0("#SBATCH --mail-user=", input$user_email, "\n#SBATCH --mail-type=ALL")
    }
    
    script_content <- template_content
    script_content <- gsub("{{PROJECT_ID}}", input$project_id, script_content, fixed = TRUE)
    script_content <- gsub("{{PLOT_TYPE}}", input$plot_type, script_content, fixed = TRUE)
    script_content <- gsub("{{Y_MIN}}", as.character(input$y_min), script_content, fixed = TRUE)
    script_content <- gsub("{{Y_MAX}}", as.character(input$y_max), script_content, fixed = TRUE)
    script_content <- gsub("{{OUTPUT_DIR}}", file.path(input$output_dir, input$project_id), script_content, fixed = TRUE)
    script_content <- gsub("{{REGIONS_FILE}}", values$selected_regions_file, script_content, fixed = TRUE)
    script_content <- gsub("{{BIGWIG_FILES}}", paste(paste0('"', values$selected_bigwig_files, '"'), collapse = " "), script_content, fixed = TRUE)
    script_content <- gsub("{{REFERENCE_POINT}}", input$reference_point, script_content, fixed = TRUE)
    script_content <- gsub("{{BEFORE_REGION}}", as.character(input$before_region), script_content, fixed = TRUE)
    script_content <- gsub("{{AFTER_REGION}}", as.character(input$after_region), script_content, fixed = TRUE)
    script_content <- gsub("{{PROCESSORS}}", input$processors, script_content, fixed = TRUE)
    script_content <- gsub("{{SKIP_ZEROS}}", skip_zeros_param, script_content, fixed = TRUE)
    script_content <- gsub("{{MISSING_DATA_AS_ZERO}}", missing_data_param, script_content, fixed = TRUE)
    script_content <- gsub("{{SAMPLE_LABELS}}", sample_labels_str, script_content, fixed = TRUE)
    script_content <- gsub("{{CPUS}}", as.character(input$sbatch_cpus), script_content, fixed = TRUE)
    script_content <- gsub("{{MEMORY}}", input$sbatch_memory, script_content, fixed = TRUE)
    script_content <- gsub("{{TIME}}", input$sbatch_time, script_content, fixed = TRUE)
    script_content <- gsub("{{PARTITION}}", input$sbatch_partition, script_content, fixed = TRUE)
    script_content <- gsub("{{ACCOUNT}}", input$sbatch_account, script_content, fixed = TRUE)
    script_content <- gsub("{{QOS_LINE}}", qos_line, script_content, fixed = TRUE)
    script_content <- gsub("{{EMAIL_LINES}}", email_lines, script_content, fixed = TRUE)
    script_content <- gsub("{{CHUNK_SIZE}}", as.character(input$chunk_size), script_content, fixed = TRUE)
    
    # Heatmap-specific parameters
    if(input$plot_type == "heatmap") {
      script_content <- gsub("{{HEATMAP_WIDTH}}", as.character(input$heatmap_width), script_content, fixed = TRUE)
      script_content <- gsub("{{X_AXIS_LABEL}}", input$x_axis_label, script_content, fixed = TRUE)
      script_content <- gsub("{{Y_AXIS_LABEL}}", input$y_axis_label, script_content, fixed = TRUE)
      script_content <- gsub("{{REGIONS_LABEL}}", input$regions_label, script_content, fixed = TRUE)
      script_content <- gsub("{{COLOR_LIST}}", input$color_list, script_content, fixed = TRUE)
      script_content <- gsub("{{SORT_USING}}", input$sort_using, script_content, fixed = TRUE)
    }
    
    # Profile-specific parameters
    if(input$plot_type == "profile") {
      script_content <- gsub("{{X_AXIS_LABEL_PROFILE}}", input$x_axis_label_profile, script_content, fixed = TRUE)
      script_content <- gsub("{{Y_AXIS_LABEL_PROFILE}}", input$y_axis_label_profile, script_content, fixed = TRUE)
      script_content <- gsub("{{PLOT_WIDTH}}", as.character(input$plot_width), script_content, fixed = TRUE)
      script_content <- gsub("{{PLOT_HEIGHT}}", as.character(input$plot_height), script_content, fixed = TRUE)
      script_content <- gsub("{{SAMPLE_GROUPS}}", gsub("\n", "\\n", input$sample_groups, fixed = TRUE), script_content, fixed = TRUE)
      
      # Process sample groups for plotting
      group_lines <- trimws(unlist(strsplit(input$sample_groups, "\n")))
      group_lines <- group_lines[group_lines != ""]
      
      # Extract sample labels and colors
      sample_labels <- sapply(group_lines, function(x) unlist(strsplit(x, ","))[1])
      sample_colors <- sapply(group_lines, function(x) unlist(strsplit(x, ","))[3])
      
      # Create strings for substitution
      sample_labels_str <- paste(sample_labels, collapse = " ")
      sample_colors_str <- paste(tolower(sample_colors), collapse = " ")  # Convert to lowercase
      
      # Substitute into template
      script_content <- gsub("{{SAMPLE_LABELS_OVERLAY}}", sample_labels_str, script_content, fixed = TRUE)
      script_content <- gsub("{{SAMPLE_COLORS_OVERLAY}}", sample_colors_str, script_content, fixed = TRUE)
    }
    
    return(paste(script_content, collapse = "\n"))
  }
  
  output$script_preview <- renderText({
    if(is.null(values$selected_bigwig_files) ||
       is.null(values$selected_regions_file) ||
       input$project_id == "" ||
       input$output_dir == "") {
      return("Please complete the required parameters above to see script preview.")
    }
    
    template_name <- paste0("templates/", input$plot_type, "_slurm.sbatch")
    generate_script_from_template(template_name)
  })
  
  output$download_script <- downloadHandler(
    filename = function() {
      paste0(input$project_id, "_", input$plot_type, "_analysis.sbatch")
    },
    content = function(file) {
      template_name <- paste0("templates/", input$plot_type, "_slurm.sbatch")
      script_content <- generate_script_from_template(template_name)
      writeLines(script_content, file)
    }
  )
  
  observeEvent(input$run_analysis, {
    if(values$analysis_running) {
      showNotification("Analysis already running!", type = "warning")
      return()
    }
    
    values$analysis_running <- TRUE
    values$output_dir <- file.path(input$output_dir, input$project_id)
    
    if(!dir.exists(values$output_dir)) {
      dir.create(values$output_dir, recursive = TRUE)
    }
    
    template_name <- paste0("templates/", input$plot_type, "_slurm.sbatch")
    script_content <- generate_script_from_template(template_name)
    script_file <- file.path(values$output_dir, paste0(input$plot_type, "_analysis.sbatch"))
    writeLines(script_content, script_file)
    
    result <- system2("sbatch", args = script_file, stdout = TRUE, stderr = TRUE)
    if(length(result) > 0 && grepl("Submitted batch job", result[1])) {
      job_id <- gsub(".*job ([0-9]+).*", "\\1", result[1])
      showNotification(paste("Job submitted successfully! Job ID:", job_id), type = "message")
      values$analysis_running <- FALSE
    } else {
      showNotification("Job submission failed!", type = "error")
      values$analysis_running <- FALSE
    }
  })
  
  output$analysis_status <- renderUI({
    if(values$analysis_running) {
      div(class = "validation-message validation-warning",
          tags$i(class = "fa fa-spinner fa-spin"),
          " Analysis in progress...")
    } else if(!is.null(values$output_dir) && dir.exists(values$output_dir)) {
      div(class = "validation-message validation-success",
          tags$i(class = "fa fa-check"),
          " Analysis directory created: ", tags$code(values$output_dir))
    }
  })
  
  output$output_files <- renderUI({
    if(!is.null(values$output_dir) && dir.exists(values$output_dir)) {
      if(input$plot_type == "heatmap") {
        expected_files <- c(
          paste0(input$project_id, "_matrix.gz"),
          paste0(input$project_id, "_heatmap.png"),
          paste0(input$project_id, "_sorted.bed")
        )
      } else {
        expected_files <- c(
          paste0(input$project_id, "_matrix.gz"),
          paste0(input$project_id, "_profiles.png")
        )
      }
      
      existing_files <- list.files(values$output_dir, pattern = paste(expected_files, collapse = "|"))
      
      if(length(existing_files) > 0) {
        div(
          h4("Generated Files:"),
          tags$ul(
            lapply(existing_files, function(f) {
              tags$li(
                tags$code(f), " - ",
                downloadLink(paste0("download_", gsub("[^a-zA-Z0-9]", "_", f)),
                             "Download",
                             class = "btn btn-sm btn-info")
              )
            })
          ),
          br(),
          div(class = "validation-message validation-success",
              tags$strong("Output Location: "),
              tags$code(values$output_dir))
        )
      } else {
        div(
          h4("Expected Output Files:"),
          tags$ul(
            lapply(expected_files, function(f) {
              tags$li(tags$code(f), " - ",
                      tags$span("Not yet generated", style = "color: #856404;"))
            })
          )
        )
      }
    }
  })
  
  # Save parameters
  output$save_params <- downloadHandler(
    filename = function() {
      paste0(ifelse(input$project_id != "", input$project_id, "analysis_params"), "_",
             format(Sys.time(), "%Y%m%d_%H%M%S"), ".json")
    },
    content = function(file) {
      params <- list(
        project_id = input$project_id,
        output_dir = input$output_dir,
        plot_type = input$plot_type,
        selected_bigwig_files = values$selected_bigwig_files,
        selected_regions_file = values$selected_regions_file,
        reference_point = input$reference_point,
        before_region = input$before_region,
        after_region = input$after_region,
        chunk_size = input$chunk_size,
        skip_zeros = input$skip_zeros,
        missing_data_as_zero = input$missing_data_as_zero,
        processors = input$processors,
        y_min = input$y_min,
        y_max = input$y_max,
        # Heatmap parameters
        heatmap_width = input$heatmap_width,
        x_axis_label = input$x_axis_label,
        y_axis_label = input$y_axis_label,
        regions_label = input$regions_label,
        color_list = input$color_list,
        sort_using = input$sort_using,
        sample_labels = input$sample_labels,
        # Profile parameters
        x_axis_label_profile = input$x_axis_label_profile,
        y_axis_label_profile = input$y_axis_label_profile,
        plot_width = input$plot_width,
        plot_height = input$plot_height,
        sample_groups = input$sample_groups,
        # Execution parameters
        sbatch_cpus = input$sbatch_cpus,
        sbatch_memory = input$sbatch_memory,
        sbatch_time = input$sbatch_time,
        sbatch_partition = input$sbatch_partition,
        sbatch_account = input$sbatch_account,
        use_burst = input$use_burst,
        user_email = input$user_email
      )
      jsonlite::write_json(params, file, pretty = TRUE)
    }
  )
  
  # Load parameters
  observeEvent(input$load_params, {
    if(is.null(input$load_params)) return()
    
    tryCatch({
      params <- jsonlite::read_json(input$load_params$datapath)
      
      # Update all inputs with proper null checking
      updateTextInput(session, "project_id", value = params$project_id %||% "")
      updateTextInput(session, "output_dir", value = params$output_dir %||% "")
      updateRadioButtons(session, "plot_type", selected = params$plot_type %||% "heatmap")
      updateSelectInput(session, "reference_point", selected = params$reference_point %||% "TSS")
      updateNumericInput(session, "before_region", value = params$before_region %||% 2000)
      updateNumericInput(session, "after_region", value = params$after_region %||% 2000)
      updateNumericInput(session, "chunk_size", value = params$chunk_size %||% 5000)
      updateCheckboxInput(session, "skip_zeros", value = params$skip_zeros %||% TRUE)
      updateCheckboxInput(session, "missing_data_as_zero", value = params$missing_data_as_zero %||% TRUE)
      updateSelectInput(session, "processors", selected = params$processors %||% "max")
      updateNumericInput(session, "y_min", value = params$y_min %||% 0)
      updateNumericInput(session, "y_max", value = params$y_max %||% 1.5)
      
      # Heatmap parameters
      updateNumericInput(session, "heatmap_width", value = params$heatmap_width %||% 6)
      updateTextInput(session, "x_axis_label", value = params$x_axis_label %||% "distance (bp)")
      updateTextInput(session, "y_axis_label", value = params$y_axis_label %||% "Genes")
      updateTextInput(session, "regions_label", value = params$regions_label %||% "ATAC")
      updateTextInput(session, "color_list", value = params$color_list %||% "white,red")
      updateSelectInput(session, "sort_using", selected = params$sort_using %||% "mean")
      updateTextAreaInput(session, "sample_labels", value = params$sample_labels %||% "")
      
      # Profile parameters
      updateTextInput(session, "x_axis_label_profile", value = params$x_axis_label_profile %||% "distance (bp)")
      updateTextInput(session, "y_axis_label_profile", value = params$y_axis_label_profile %||% "mean RPKM")
      updateNumericInput(session, "plot_width", value = params$plot_width %||% 8)
      updateNumericInput(session, "plot_height", value = params$plot_height %||% 6)
      updateTextAreaInput(session, "sample_groups", value = params$sample_groups %||% "")
      
      # Execution parameters
      updateRadioButtons(session, "execution_method", selected = params$execution_method %||% "direct")
      updateNumericInput(session, "sbatch_cpus", value = params$sbatch_cpus %||% 8)
      updateTextInput(session, "sbatch_memory", value = params$sbatch_memory %||% "32G")
      updateTextInput(session, "sbatch_time", value = params$sbatch_time %||% "4:00:00")
      updateTextInput(session, "sbatch_partition", value = params$sbatch_partition %||% "hpg-default")
      updateTextInput(session, "sbatch_account", value = params$sbatch_account %||% "")
      updateCheckboxInput(session, "use_burst", value = params$use_burst %||% FALSE)
      updateTextInput(session, "user_email", value = params$user_email %||% "")
      
      # Handle file selections
      if(!is.null(params$selected_bigwig_files)) {
        if(is.list(params$selected_bigwig_files)) {
          values$selected_bigwig_files <- unlist(params$selected_bigwig_files)
        } else {
          values$selected_bigwig_files <- params$selected_bigwig_files
        }
      } else {
        values$selected_bigwig_files <- NULL
      }
      
      if(!is.null(params$selected_regions_file)) {
        if(is.list(params$selected_regions_file)) {
          values$selected_regions_file <- unlist(params$selected_regions_file)[1]
        } else {
          values$selected_regions_file <- params$selected_regions_file
        }
      } else {
        values$selected_regions_file <- NULL
      }
      
      showNotification("Parameters loaded successfully!", type = "message")
    }, error = function(e) {
      showNotification(paste("Error loading parameters:", e$message), type = "error")
    })
  })
  
  observe({
    # Add this check at the very beginning
    if(is.null(values$output_dir) || !dir.exists(values$output_dir)) {
      return()
    }
    
    files <- list.files(values$output_dir, full.names = TRUE)
    if(length(files) > 0) {
      for(i in seq_along(files)) {
        file_path <- files[i]
        file_name <- basename(file_path)
        # Make sure handler_id is never empty
        handler_id <- paste0("download_", gsub("[^a-zA-Z0-9]", "_", file_name))
        if(handler_id == "download_" || nchar(handler_id) <= 9) {
          next  # skip if the handler_id would be invalid
        }
        
        local({
          local_file_path <- file_path
          local_file_name <- file_name
          output[[handler_id]] <- downloadHandler(
            filename = function() local_file_name,
            content = function(file) {
              file.copy(local_file_path, file)
            }
          )
        })
      }
    }
  })
}

shinyApp(ui = ui, server = server)
  