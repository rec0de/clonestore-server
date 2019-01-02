# Data Format documentation v0.1.0

## Versioning

The API specification follows semantic versioning principles.  
Patch version bumps and minor version bumps should be backwards compatible (1.2.1 to 1.3.1 or 1.3.1 to 1.3.2) while incompatible versions result in a major version change (1.2.1 to 2.0.0).

## Plasmids

Plasmids are represented as JSON Objects of the following structure:

| Property    | Required? | Description                                | Example value |
| ----------- | --------- | ------------------------------------------ | ------------- |
| id          | no        | Unique identifier of the plasmid.          | `pKV42`       |
| name        | yes       | Name of the plasmid, arbitrary string      | `TestPlasmid` |
| initials    | yes       | Initials of the plasmid's creator          | `KV`          |
| description | no        | Free-text description of the plasmid       | --            |
| timeOfCreation | yes    | UNIX timestamp of the plasmids creation time| `1546441000` |
| timeOfEntry | no        | UNIX timestamp when the plasmid was added  | `1546442964`  |
| features    | no        | List of plasmid features (strings)         | `["Magnicon","Terminator"]` |
| selectionMarkers | no   | List of selectionMarkers (strings)         | `["Tetracyclin"]` |
| geneData    | no        | DNA basepair data of the plasmid, in .gb format | --       |

Fields marked as required must be present when adding a new plasmid, others may be set automatically (id, timeOfEntry) or can be added later.