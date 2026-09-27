# Lufy Asamblea feed `lufy.asamblea.v1`

Shared contract for the daily public-role file under GitHub Pages at `/data/app/v1/`.
Lufy Aprende reads it. The sibling app can write the same files. This folder is the schema to unify on. There is no `apple/` feed on this branch yet.

`manifest.json` and `asamblea.json` in this folder are **EXAMPLE DATA**. Names, parties and votes are fictional. Replace both files with the real daily extract before anyone treats the URL as the roll of the Asamblea Nacional.

## manifest.json

```json
{
  "schema": "lufy.asamblea.v1",
  "updated_at": "YYYY-MM-DD",
  "example_data": false,
  "files": [
    { "name": "asamblea.json", "sha256": "<lowercase hex of the exact file bytes>" }
  ]
}
```

The app downloads the manifest at most once per civil day in `America/Guayaquil`. It then downloads `asamblea.json` from the same directory, checks `sha256`, and only then replaces the last good copy. A mismatch or a failed check keeps the previous copy.

## asamblea.json

```json
{
  "schema": "lufy.asamblea.v1",
  "example_data": false,
  "updated_at": "YYYY-MM-DD",
  "source": {
    "institution": "Asamblea Nacional del Ecuador",
    "dataset": "name of the public register",
    "date": "YYYY-MM-DD",
    "note": "short description of what the extract contains"
  },
  "legislators": [
    {
      "id": "stable-public-id",
      "public_name": "name used in the public office",
      "district_kind": "province",
      "district": "Guayas",
      "party": "organization or bench, or empty",
      "committees": ["commission name"],
      "votes": [
        {
          "date": "YYYY-MM-DD",
          "title": "what was voted, in neutral words",
          "choice": "afavor",
          "source": "institution, document, date"
        }
      ]
    }
  ]
}
```

`district_kind` is `province`, `national` or `exterior`.
For `province`, `district` is the province name (`Guayas`, `Pichincha`, `Manabí`, …).
For the other two kinds, `district` is `Nacional` or `Exterior`.

`choice` is `afavor`, `encontra`, `abstencion`, `ausente` or `blanco`.
Every vote needs a non-empty `source`.

## Allowed and rejected

Public role only: name in office, district, party or bench, committees, recorded vote and its source line.

Optional `photo` only when the image is public domain or CC BY / CC BY-SA, with `url`, `author`, `license`, `license_url` and `source_url`. The sample file has no photos.

The reader rejects the file if it finds:

- keys that carry a cédula, email, phone, address, family relationship or personal assets
- the words corrupto, culpable, testaferro or delincuente
- a 10-digit number or an email address in any text
- a photo without an open license, author and source

Do not add those fields under another name. The app will not show them.
