# Column Comments Enrichment — Data Flow Diagram

## End-to-End Data Flow

```mermaid
flowchart TD
    %% User input
    User["User<br>(run.sh)"] -->|"configures target table<br>+ confluence pages"| Config[".env.local<br>+ config/&lt;db&gt;/&lt;table&gt;.yaml"]

    %% Launch
    Config --> RunSh["run.sh<br>(foreground orchestrator<br>+ trap INT/TERM)"]
    MuEnv["~/.config/mu/mu.env<br>(MOONUNIT_* credentials)"] --> RunSh
    RunSh -->|"mu lint (pre-flight)"| RunSh
    RunSh -->|"mu launch<br>--mount-workspace &lt;host-path&gt;<br>--keep-container"| MU["mu CLI<br>(agent runner)"]

    %% Bootstrap: bind mount instead of ephemeral FS
    MU -->|"pulls image,<br>bind-mounts workspace,<br>clones repo into it"| Docker["Docker Container<br>/tmp/moonunit-workspace<br>↔ host: output/&lt;db&gt;/&lt;table&gt;/.workspace"]

    %% Stage 1: Research
    subgraph Research["Stage 1: Research"]
        direction TB
        R_DDL["Read repos/lake/.../table.ddl"]
        R_YAML["Read table.yaml<br>(metadata + lineage)"]
        R_Confluence["Fetch Confluence Pages<br>(design specs, column mappings)"]
        R_Alation_Target["Fetch Target Table Columns<br>(description + column_comment)"]
        R_Alation_Ref["Fetch Reference Table Columns<br>(column_comment = Source Comments)"]
        R_Dictionary["Fetch Certified Data Dictionary<br>(official term definitions)"]
        R_Output["research.md<br>(consolidated findings)"]

        R_DDL --> R_Output
        R_YAML --> R_Output
        R_Confluence --> R_Output
        R_Alation_Target --> R_Output
        R_Alation_Ref --> R_Output
        R_Dictionary --> R_Output
    end

    %% Stage 2: Enrich — rewrites the in-repo table.ddl in place
    subgraph Enrich["Stage 2: Enrich"]
        direction TB
        E_Input["Read research.md"]
        E_Standard["Apply Column Description Standard<br>(annotations, 255-char target,<br>official terminology)"]
        E_WriteRepo["Overwrite repos/lake/.../table.ddl<br>in the cloned repo (in-place)"]

        E_Input --> E_Standard
        E_Standard --> E_WriteRepo
    end

    %% Stage 3: Validate — enforces hard 255-char limit
    subgraph Validate["Stage 3: Validate"]
        direction TB
        V_Read["Read enriched table.ddl"]
        V_Check["Check every COMMENT ≤ 255 chars"]
        V_Condense["If any overflow: condense<br>(never mid-word truncation)"]
        V_FinalRepo["Final repos/lake/.../table.ddl<br>(compliant DDL)"]

        V_Read --> V_Check
        V_Check --> V_Condense
        V_Condense --> V_FinalRepo
    end

    %% Stage flow
    Docker --> Research
    Research --> Enrich
    Enrich --> Validate

    %% Launcher-side snapshots at stage boundaries (filesystem watch, no docker cp)
    Docker -. "copy once at<br>state=BOOTSTRAP_COMPLETE" .-> OriginalSnap["output/.../original-table.ddl"]
    Enrich -. "copy on<br>'Finished stage: enrich'" .-> EnrichedSnap["output/.../enriched-table.ddl"]
    Validate -. "copy at<br>state=SUCCEEDED" .-> ValidatedSnap["output/.../validated-table.ddl"]

    %% External data sources
    GitHub["GitHub<br>gdcorp-dna/lake<br>(DDL + table.yaml)"] -->|"git clone (read-only)"| Docker
    Confluence["Confluence<br>godaddy-corp.atlassian.net<br>(design specs)"] -->|"REST API<br>(MOONUNIT_JIRA creds)"| R_Confluence
    Alation_Tables["Alation<br>Table + Column API<br>(descriptions + source comments)"] -->|"REST API<br>(MOONUNIT_ALATION creds)"| R_Alation_Target
    Alation_Tables -->|"REST API"| R_Alation_Ref
    Alation_Dict["Alation<br>Document Folder 6<br>(Certified Data Dictionary)"] -->|"REST API"| R_Dictionary

    %% Post-success: generate comparison + notify
    ValidatedSnap --> CompareGen["run.sh generates<br>ddl-comparison.md<br>(original | enriched | validated)"]
    OriginalSnap --> CompareGen
    EnrichedSnap --> CompareGen
    CompareGen --> Output["output/&lt;db&gt;/&lt;table&gt;/<br>original/enriched/validated-table.ddl<br>research.md, INPUT.md, ddl-comparison.md"]
    Output -->|"macOS notification<br>+ success banner"| User

    %% Styling
    classDef user fill:#4A90D9,stroke:#2C5F8A,color:#fff
    classDef config fill:#F5A623,stroke:#C07D18,color:#fff
    classDef infra fill:#9B6FB0,stroke:#6D4E7D,color:#fff
    classDef external fill:#7BC67E,stroke:#4A8A4D,color:#fff
    classDef stage fill:#E8E8E8,stroke:#999,color:#333
    classDef output fill:#D64541,stroke:#A33330,color:#fff
    classDef snap fill:#F4D35E,stroke:#C4A42C,color:#333

    class User user
    class Config,MuEnv config
    class RunSh,MU,Docker,CompareGen infra
    class GitHub,Confluence,Alation_Tables,Alation_Dict external
    class OriginalSnap,EnrichedSnap,ValidatedSnap snap
    class Output output
```

## Research Stage — Data Sources Detail

```mermaid
flowchart LR
    subgraph Sources["External Data Sources"]
        S1["GitHub Repo<br>(gdcorp-dna/lake)"]
        S2["Confluence Pages<br>(from config.yaml)"]
        S3["Alation Target Table<br>(db_name.table_name)"]
        S4["Alation Reference Tables<br>(optional, from config.yaml)"]
        S5["Certified Data Dictionary<br>(Folder 6, 100+ docs)"]
    end

    subgraph Extracted["Data Extracted"]
        E1["Column names, types, order<br>Existing COMMENT clauses"]
        E2["Column-to-source mappings<br>Business logic<br>Composite primary key definition"]
        E3["column_comment (Source Comments)<br>description (user-authored)<br>Table-level metadata"]
        E4["column_comment (Source Comments)<br>from predecessor/successor DDL<br>Table description + use cases"]
        E5["Official abbreviation expansions<br>(GCR, NRU, MRR, COGS, etc.)"]
    end

    S1 --> E1
    S2 --> E2
    S3 --> E3
    S4 --> E4
    S5 --> E5

    subgraph Output["research.md"]
        O1["Full DDL"]
        O2["Metadata + lineage"]
        O3["Confluence summary"]
        O4["Alation column data<br>(descriptions + source comments)"]
        O5["Dictionary Mappings table"]
        O6["Per-column analysis"]
    end

    E1 --> O1
    E1 --> O2
    E2 --> O3
    E3 --> O4
    E4 --> O4
    E5 --> O5
    E1 & E2 & E3 & E4 & E5 --> O6
```

## Enrich + Validate Stages — Transformation Rules

```mermaid
flowchart TD
    Input["research.md"] --> Parse["Parse column list<br>+ all gathered context"]

    Parse --> Rules{"Apply Enrich Rules"}

    Rules --> R1["1. Every column gets a COMMENT"]
    Rules --> R2["2. Target ≤ 255 characters"]
    Rules --> R3["3. Use official Dictionary terms<br>(GCR = Gross Cash Receipts)"]
    Rules --> R4["4. Add @PrimaryKey, @ForeignKey,<br>@Enumerated annotations"]
    Rules --> R5["5. Include units (USD, trxn currency)"]
    Rules --> R6["6. Preserve existing annotations<br>(Employee PII, etc.)"]
    Rules --> R7["7. Audit columns note timezone"]
    Rules --> R8["8. Semantic-rich for AI search"]

    R1 & R2 & R3 & R4 & R5 & R6 & R7 & R8 --> Enriched["Enriched table.ddl<br>(overwrites in-repo file)"]

    Enriched --> ValidateAgent{"Stage 3: Validate agent<br>reads every COMMENT"}
    ValidateAgent --> Check{"Any comment &gt; 255?"}

    Check -->|"No"| FinalDDL["Final table.ddl<br>(unchanged)"]
    Check -->|"Yes"| Condense["Condense rules (in order):<br>1. Drop parenthetical synonyms<br>2. Shorten verbose qualifiers<br>3. Trim @Enumerated lists<br>4. Drop secondary context<br>5. Tighter phrasing<br>6. Abbreviate where safe"]
    Condense -->|"NEVER mid-word truncation"| Recheck{"All ≤ 255?"}
    Recheck -->|"No"| Condense
    Recheck -->|"Yes"| FinalDDL
```

## Credential Flow

```mermaid
flowchart LR
    subgraph Host["Host Machine"]
        EnvLocal[".env.local<br>(AWS_PROFILE, etc.)"]
        MuEnv["~/.config/mu/mu.env"]
    end

    subgraph MuEnvVars["mu.env Contents"]
        MJ["MOONUNIT_JIRA<br>{url, email, api_token}"]
        MA["MOONUNIT_ATLASSIAN<br>{email, api_token}"]
        MAL["MOONUNIT_ALATION<br>{url, refresh_token, user_id}"]
        MG["MOONUNIT_GOCODE<br>{ANTHROPIC_BASE_URL, ANTHROPIC_AUTH_TOKEN}"]
        MGH["MOONUNIT_GITHUB_TOKEN<br>{token}"]
    end

    subgraph Container["Docker Container (agent)"]
        NodeParse["node -e 'JSON.parse(...)'"]
        ConfCreds["Confluence creds<br>(email:api_token)"]
        AlatToken["Alation API token<br>(via createAPIAccessToken)"]
    end

    subgraph APIs["API Calls"]
        ConfAPI["Confluence REST API"]
        AlatAPI["Alation REST API"]
        GoCodeAPI["GoCode (Claude)"]
        GhAPI["GitHub API"]
    end

    MuEnv --> MuEnvVars
    MJ -->|"passed to container"| NodeParse
    MA -->|"passed to container"| NodeParse
    MAL -->|"passed to container"| NodeParse
    NodeParse --> ConfCreds
    NodeParse --> AlatToken
    ConfCreds --> ConfAPI
    AlatToken --> AlatAPI
    MG -->|"auto-configured by mu"| GoCodeAPI
    MGH -->|"auto-configured by mu"| GhAPI
```
