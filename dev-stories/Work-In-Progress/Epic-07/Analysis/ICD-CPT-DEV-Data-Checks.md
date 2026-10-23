# ICD/CPT — DEV Data Checks (read-only)

**From:** Hem Singh · **Updated:** 2026-10-21
**Purpose:** close the data questions the code can't answer: whether the tables are current, the dot format, the date
format, which code families are present, and whether saved codes match the tables.
**How to run:**
- On the DEV database (VPN), in SSMS or Azure Data Studio.
- Every query is a `SELECT`.
- The queries against encounter tables return **counts only**, with no patient rows, so the results can be pasted here.

Column names are checked against `pacEHR_API` `dc7316ec3`.

| # | Question | Feeds |
|---|---|---|
| 1 | How many rows, and how many distinct codes? | P1, A2 |
| 2 | Are ICD codes stored dotted and upper-case? | D2 |
| 3 | What format are the ICD `startDate`/`endDate` strings in? | A2 |
| 4 | What do the tables say for the codes in the screenshots? | A3, the `S83.241A` and `99234` findings |
| 5 | Which code families are in `DATA.cptCodes`, and with which first letters? | D3 (HCPCS letters, PLA) |
| 6 | How many rows per code (versions)? | A2 |
| 7 | How current are the tables? | P1 |
| 8 | Do codes saved in the last 6 months exist in the tables? | P1, A2: the size of the real gap |

---

### 1. Row counts

```sql
SELECT 'icdCodes' AS tbl, COUNT(*) AS totalRows, COUNT(DISTINCT code) AS distinctCodes FROM DATA.icdCodes
UNION ALL
SELECT 'cptCodes', COUNT(*), COUNT(DISTINCT code) FROM DATA.cptCodes;
```

### 2. ICD dot format and case

```sql
SELECT
    SUM(CASE WHEN code LIKE '%.%' THEN 1 ELSE 0 END)                                AS dotted,
    SUM(CASE WHEN code NOT LIKE '%.%' AND LEN(code) > 3 THEN 1 ELSE 0 END)          AS undottedLongerThan3,
    SUM(CASE WHEN LEN(code) = 3 THEN 1 ELSE 0 END)                                  AS threeCharacter,
    SUM(CASE WHEN code COLLATE Latin1_General_CS_AS <> UPPER(code) THEN 1 ELSE 0 END) AS notUpperCase
FROM DATA.icdCodes;
```

### 3. ICD date strings

```sql
-- The shapes of the strings
SELECT LEN(startDate) AS startLen, MIN(startDate) AS example, COUNT(*) AS n
FROM DATA.icdCodes GROUP BY LEN(startDate) ORDER BY n DESC;

-- A few known codes
SELECT code, startDate, endDate, isActive, billable, isDelete, billableDate, isActiveDate
FROM DATA.icdCodes
WHERE code IN ('E11.9', 'E11.19', 'I10', 'Z79.4', 'S83.211A', 'S83.241A', 'U07.1');
```

### 4. The codes from the screenshots

```sql
SELECT code, Description, billable, isActive
FROM DATA.icdCodes
WHERE code IN ('S83.211A', 'S83.241A', 'I10', 'E11.9', 'Z79.4');

SELECT code, codeShortDesc, codeLongDesc, userFriendlyDescription, startDate, endDate
FROM DATA.cptCodes
WHERE code IN ('99234', '99235', '99327', '99213', '20610', '73562', '36415', '80053', '83036', 'G2211');
```

What to look for:
- **ICD:** the `Description` of `S83.241A` against what screenshot 1 showed.
- **99234:** whether `codeShortDesc` still has the pre-2023 "history and examination" wording.
- **99327:** whether it has an `endDate` (it was deleted in 2023).

### 5. CPT/HCPCS families and leading letters

```sql
SELECT f.family, COUNT(*) AS n, MIN(c.code) AS example
FROM DATA.cptCodes c
CROSS APPLY (SELECT CASE
    WHEN c.code LIKE '[0-9][0-9][0-9][0-9][0-9]' THEN 'CPT Cat I'
    WHEN c.code LIKE '[0-9][0-9][0-9][0-9]F'     THEN 'CPT Cat II'
    WHEN c.code LIKE '[0-9][0-9][0-9][0-9]T'     THEN 'CPT Cat III'
    WHEN c.code LIKE '[0-9][0-9][0-9][0-9]U'     THEN 'PLA'
    WHEN c.code LIKE '[A-Z][0-9][0-9][0-9][0-9]' THEN 'HCPCS II'
    ELSE 'other' END AS family) f
GROUP BY f.family
ORDER BY n DESC;

-- HCPCS leading letters (settles the [A-V] placeholder in the PEA-704 pattern)
SELECT LEFT(code, 1) AS firstLetter, COUNT(*) AS n
FROM DATA.cptCodes
WHERE code LIKE '[A-Z][0-9][0-9][0-9][0-9]'
GROUP BY LEFT(code, 1)
ORDER BY firstLetter;

-- Anything that fits none of the shapes
SELECT TOP 20 code
FROM DATA.cptCodes
WHERE code NOT LIKE '[0-9][0-9][0-9][0-9][0-9]'
  AND code NOT LIKE '[0-9][0-9][0-9][0-9][FTU]'
  AND code NOT LIKE '[A-Z][0-9][0-9][0-9][0-9]';
```

### 6. Rows per code

```sql
SELECT TOP 20 code, COUNT(*) AS versions, MIN(startDate) AS firstStart, MAX(endDate) AS lastEnd
FROM DATA.cptCodes GROUP BY code HAVING COUNT(*) > 1 ORDER BY versions DESC;

SELECT TOP 20 code, COUNT(*) AS versions
FROM DATA.icdCodes GROUP BY code HAVING COUNT(*) > 1 ORDER BY versions DESC;
```

### 7. How current the tables are

```sql
SELECT MAX(startDate) AS newestStart,
       MAX(endDate)   AS newestEnd,
       SUM(CASE WHEN endDate < CAST(GETDATE() AS date) THEN 1 ELSE 0 END) AS endedRows
FROM DATA.cptCodes;

SELECT MAX(createdDate) AS lastCreated, MAX(lastmodifieddate) AS lastModified,
       MAX(billableDate) AS lastBillableChange
FROM DATA.icdCodes;
```

- **ICD-10-CM** changes every 1 October, **plus interim 1 April updates** (FY23–FY26 all had one).
- **CPT** changes every 1 January, plus quarterly PLA and Category III releases.

Data older than the latest release means the tables are behind. For ICD, compare the count of `billable = 1` codes with the NCHS order file's valid codes: **74,719 for FY2026**.

### 8. Saved codes against the tables (counts only)

```sql
-- ICD saved on encounters in the last 6 months
SELECT COUNT(*) AS savedDiagnoses,
       SUM(CASE WHEN NOT EXISTS (SELECT 1 FROM DATA.icdCodes i WHERE i.code = ed.code) THEN 1 ELSE 0 END) AS notInIcdTable,
       SUM(CASE WHEN EXISTS (SELECT 1 FROM DATA.icdCodes i WHERE i.code = ed.code AND i.billable = 0) THEN 1 ELSE 0 END) AS savedButNotBillable,
       SUM(CASE WHEN ed.code NOT LIKE '%.%' AND LEN(ed.code) > 3 THEN 1 ELSE 0 END) AS undotted
FROM Encounter.encounterDiagnosis ed
WHERE ed.IsDeleted = 0
  AND ed.createdDate >= DATEADD(month, -6, GETDATE());

-- Same code saved with different descriptions on the same encounter (the (code, description) dedupe gap)
SELECT COUNT(*) AS encounterCodePairsWithMoreThanOneDescription
FROM (
    SELECT encounterID, code
    FROM Encounter.encounterDiagnosis
    WHERE IsDeleted = 0 AND createdDate >= DATEADD(month, -6, GETDATE())
    GROUP BY encounterID, code
    HAVING COUNT(DISTINCT description) > 1
) x;

-- CPT saved on encounters in the last 6 months
SELECT COUNT(*) AS savedCpt,
       SUM(CASE WHEN NOT EXISTS (SELECT 1 FROM DATA.cptCodes c WHERE c.code = ec.code) THEN 1 ELSE 0 END) AS notInCptTable,
       SUM(CASE WHEN ec.code LIKE '[A-Z][0-9][0-9][0-9][0-9]' THEN 1 ELSE 0 END) AS hcpcsShaped
FROM Encounter.encounterCPT ec
WHERE ec.createdDate >= DATEADD(month, -6, GETDATE());
```

## Results

Paste the results here with the date they were run, then update the decisions in the [README](../README.md).

| # | Run on | Result | Conclusion |
|---|---|---|---|
| 1 | 2026-10-22 | ICD: 364,282 rows, 74,321 distinct codes, 228,853 usable rows (billable, active, not deleted). CPT: 24,775 rows, 24,767 codes | ICD has about 5 rows per code, mostly IMO wordings. 74,321 codes is close to the NCHS FY2026 count. **A per-run substring search over these rows is too slow** (see below) |
| 2 | 2026-10-22 | 361,316 rows with a dot, 0 dot-less codes longer than 3, 2,966 three-character codes | D2 confirmed: ICD is stored dotted |
| 3 | 2026-10-22 | `startDate`/`endDate` are **NULL on every ICD row** | An ICD date-of-service check is impossible. ICD validity rests on `isActive` and `billable` only |
| 4 | — | Not run | — |
| 5 | 2026-10-22 | CPT families: Cat I 12,546; HCPCS 10,581; "other" 703 (e.g. `0001M`, MAAA); Cat II 603; Cat III 342; **PLA 0**. HCPCS letters A–V, plus local X (1), Y (257), Z (676). Two internal rows: `00000` "Non-Billable Discharge Event" and `99999` "Non-Billable Event" | D3 confirmed: `[A-V]` is right and PLA stays out. MAAA (`####M`) is out of Phase 1. The two Non-Billable rows are now excluded from search and lookup |
| 6 | 2026-10-22 | ICD: up to 162 rows per code (`Z23`). CPT: at most 2 rows per code | Search groups by code; lookup picks one row |
| 7 | 2026-10-22 | CPT: 24,736 of 24,782 rows start 2020-01-01, **every row ends 2027-01-01**. Deleted codes are present with those dates (`99311`–`99313`, `99327`), and so are non-CPT codes (`658`, `90300`). Descriptions are custom (`99309` "[30 min] Moderate MDM"). ICD: last created 2026-01-06, never modified | **The CPT dates are placeholders:** the date-of-service check never rejects, and deleted codes pass as valid. Raise with the legacy team (meeting Q1). ICD's January 2026 load may miss the April 2026 interim update |
| 8 | — | Not run | — |

**Also measured on 2026-10-22:**
- `DATA.restrictedCPTByPOS` has 56 rows: 6 POS ids, 2 POS names, 18 codes.
- The eval encounter `5112465` has `POS = 11` (office), while the eval context says "Group Home".
- The database collation is `SQL_Latin1_General_CP1_CI_AS`.

**Search timing** (from this machine over the VPN; a bare `SELECT 1` takes about 480 ms):

| Query | Time |
|---|---|
| Current search, 1 term | 1.9 s |
| Current search, 3 terms | 3.8 s |
| Current search, 10 terms | over 10 s (timed out) |
| One scan for all words, binary collation, 10 terms | 5.7 s |

The ranking was poor in every variant. "heart failure" returned thyrotoxicosis and rheumatic codes before `I50.9`,
because `UsageCount` is mostly 0 and ties fall back to alphabetical order. **How search should work is open**
(implementation plan, C5).
