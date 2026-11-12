// =============================================================================
// Power Query: SalesExports
// Reads every monthly order export (CSV) in one folder, cleans it, and loads
// one table to the Data sheet (cell A1). Refresh with Data > Refresh All.
//
// Setup (once): Data > Get Data > From Other Sources > Blank Query >
//               Advanced Editor > paste this code > change FolderPath below.
// =============================================================================
let
    // 1. Folder that holds the exports. Change this path once, keep the final backslash.
    FolderPath = "C:\SalesDashboard\exports\",

    // 2. Every CSV file in the folder (ignores other files and Excel lock files)
    Source = Folder.Files(FolderPath),
    CsvFiles = Table.SelectRows(
        Source,
        each Text.Lower([Extension]) = ".csv" and not Text.StartsWith([Name], "~")
    ),

    // 3. Read each file and use its first row as column names
    Parsed = Table.AddColumn(
        CsvFiles,
        "Rows",
        each Table.PromoteHeaders(
            Csv.Document([Content], [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
            [PromoteAllScalars = true]
        )
    ),

    // 4. Stack all months into one table
    Combined = Table.Combine(Parsed[Rows]),

    // 5. Drop blank lines (exports often end with one)
    NoBlankRows = Table.SelectRows(Combined, each [Order ID] <> null and [Order ID] <> ""),

    // 6. Column types. "en-US" makes dates and decimals read the same on every PC,
    //    whatever the Windows regional settings are.
    Typed = Table.TransformColumnTypes(
        NoBlankRows,
        {
            {"Order ID", type text}, {"Line Item", Int64.Type}, {"Order Date", type date},
            {"Customer ID", type text}, {"Country", type text}, {"SKU", type text},
            {"Product Name", type text}, {"Category", type text}, {"Subcategory", type text},
            {"Quantity", Int64.Type}, {"Unit Price", type number}, {"Line Total", type number},
            {"Unit Cost", type number}, {"Tax", type number}, {"Shipping", type number}
        },
        "en-US"
    ),

    // 7. Fix inconsistent text: extra spaces in product names, capitalization of categories
    CleanText = Table.TransformColumns(
        Typed,
        {
            {"Product Name", each Text.Combine(List.Select(Text.Split(Text.Trim(_), " "), each _ <> ""), " "), type text},
            {"Category", each Text.Proper(Text.Trim(_)), type text},
            {"Country", each Text.Trim(_), type text}
        }
    ),

    // 8. Remove exact duplicate rows (the same line exported twice)
    NoDuplicates = Table.Distinct(CleanText),

    // 9. Helper columns used by the dashboard
    AddMonth = Table.AddColumn(NoDuplicates, "Month", each Date.StartOfMonth([Order Date]), type date),
    AddLineCost = Table.AddColumn(AddMonth, "Line Cost", each [Unit Cost] * [Quantity], type number),

    // 10. Column order must match the Data sheet (A to Q); the dashboard reads columns by position
    Result = Table.SelectColumns(
        AddLineCost,
        {
            "Order ID", "Line Item", "Order Date", "Month", "Customer ID", "Country", "SKU",
            "Product Name", "Category", "Subcategory", "Quantity", "Unit Price", "Line Total",
            "Unit Cost", "Line Cost", "Tax", "Shipping"
        }
    )
in
    Result
