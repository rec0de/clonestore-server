# API documentation v0.1.0

## Versioning

The API specification follows semantic versioning principles.  
Patch version bumps and minor version bumps should be backwards compatible (1.2.1 to 1.3.1 or 1.3.1 to 1.3.2) while incompatible versions result in a major version change (1.2.1 to 2.0.0).
The current API version can be queried by a GET request to the API root.

## Authentication

Authentication is managed by the `Authenticator` class found in `auth.class.rb`. As the means of authentication vary widely by your desired usecase, this class only provides demo functionality.

In general, authenticating a user works by calling the `auth` endpoint with some sort of authentication token which is then verified by the Authenticator class. If the token is valid (in the demo implementation a token is valid if and only if it is the string `testtoken`), the API call will return a `sessionToken` that is valid for a certain timeframe and can be used to authenticate subsequent requests by sending it alongside the request as a parameter.

Calling an API endpoint that requires authentication without a valid `sessionToken` will result in a response of type `authError`.

## Methods

The API consists of five endpoints, `plasmid`, `storage`, `search`, `print` and `auth`, as well as the root endpoint.

### Server info

`GET /`

Returns a JSON Object including the server version.

| Property   | Format | Description                                |
| ---------- | ------ | ------------------------------------------ |
| type       | text   | Constant string `clonestore-server`        |
| version    | text   | Current version of the server              |

### Authentication

`POST /auth`

Issues a new session token to authenticate subsequent API calls, provided that the given authentication token is valid. Returns an error, otherwise.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| token      | text   | Authentication token                               |

| Property   | Format | Description                                |
| ---------- | ------ | ------------------------------------------ |
| type       | text   | Constant string `sessionToken`             |
| sessionToken | text | New session token to be used for authentication |

### Viewing a plasmid

`GET /plasmid/[id]`

Returns a JSON representation of the requested plasmid if found, or a 404 error otherwise.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| id         | text   | Unique ID of the requested plasmid, format `pXY0123` |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `plasmid`                          |
| plasmid    | json   | The requested plasmid JSON representation          |

### Creating a plasmid

`POST /plasmid`

Adds a new plasmid to the database. If the plasmid supplied does not have an ID, a new one will be generated using sequential numbering. The provided plasmid data should contain values for all fields marked as required in the data format documentation.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| data       | text   | JSON-representation of the plasmid to be added     |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `objectID`                         |
| id         | text   | Unique ID of the inserted plasmid, format `pXY123`  |

### Archiving a plasmid

`DELETE /plasmid/[id]`

Mark a plasmid as archived without actually deleting any information. This frees the plasmid's storage location and prevents it from showing up in search results when not explicitly requested. Viewing the plasmid data using its unique ID will still work as before.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| id         | text   | Unique ID of the requested plasmid, format `pXY123` |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `success`                          |
| details    | text   | Human-readable status information                  |

### Setting a plasmid storage location

`PUT /storage/[location]`

Marks the given storage slot as occupied by the given plasmid. The location has to be free for the request to succeed. Storage locations can be arbitrary strings, so care should be taken (on the client side) that location formatting is uniform. Otherwise two locations referring to the same physical location may store different plasmids, creating inconsistencies.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| location   | text   | Canonical name of the storage slot, must be unique |
| entry      | text   | Unique ID of the plasmid to be stored              |
| host       | text   | Bacterial host of the sample to be stored          |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `success`                          |
| details    | text   | Human-readable status information                  |

### Querying a storage location

`GET /storage/loc/[location]`

Retrieves the ID of the plasmid stored in the given location. Returns a 404 Error if the storage slot is empty.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| location   | text   | Canonical name of the storage slot                 |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `storageLocationContent`           |
| id         | text   | Unique ID of the stored plasmid, format `pXY123`   |
| host       | text   | Bacterial host of the stored plasmid               |

### Searching plasmid locations

`GET /storage/id/[id]`

Returns all locations the given plasmid is currently stored at, including the respective bacterial hosts. Returns an empty list if the plasmid is not stored anywhere.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| id         | text   | Unique ID of the plasmid                           |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `storageLocationList`              |
| locations  | array  | Array of storage location objects                  |

The objects in the `locations` list have the following properties:

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| location   | text   | Canonical name of the storage slot of this sample  |
| host       | text   | Name of the bacterial host                         |


### Freeing a plasmid storage location

`DELETE /storage/[location]`

Marks the given storage slot as empty and available for new plasmids.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| location   | text   | Canonical name of the storage slot                 |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `success`                          |
| details    | text   | Human-readable status information                  |

### Viewing a microorganism

`GET /organism/[id]`

Returns a JSON representation of the requested microorganism if found, or a 404 error otherwise.

| Parameter  | Format | Description                                           |
| ---------- | ------ | ----------------------------------------------------- |
| id         | text   | Unique ID of the requested organism, format `mXY0123` |

| Property   | Format | Description                                           |
| ---------- | ------ | ----------------------------------------------------- |
| type       | text   | Constant string `microorganism`                       |
| microorganism | json   | The requested microorganism JSON representation    |

### Creating a microorganism

`POST /organism`

Adds a new microorganism to the database. If the organism supplied does not have an ID, a new one will be generated using sequential numbering.

| Parameter  | Format | Description                                               |
| ---------- | ------ | --------------------------------------------------------- |
| data       | text   | JSON-representation of the microorganism to be added      |

| Property   | Format | Description                                               |
| ---------- | ------ | --------------------------------------------------------- |
| type       | text   | Constant string `objectID`                                |
| id         | text   | Unique ID of the inserted microorganism, format `mXY123`  |

### Archiving a microorganism

`DELETE /organism/[id]`

Mark a microorganism as archived without actually deleting any information. Viewing the organism data using its unique ID will still work as before.

| Parameter  | Format | Description                                               |
| ---------- | ------ | --------------------------------------------------------- |
| id         | text   | Unique ID of the requested microorganism, format `mXY123` |

| Property   | Format | Description                                               |
| ---------- | ------ | --------------------------------------------------------- |
| type       | text   | Constant string `success`                                 |
| details    | text   | Human-readable status information                         |

### Changing a microorganism storage location

`PUT /organism/[id]/storageLocation`

Changes the storage location of the specified microorganism to the supplied location.

| Parameter  | Format | Description                                               |
| ---------- | ------ | --------------------------------------------------------- |
| id         | text   | Unique ID of the requested microorganism, format `mXY123` |
| newLocation | text  | Canonical name of the storage location, must be unique    |

| Property   | Format | Description                                               |
| ---------- | ------ | --------------------------------------------------------- |
| type       | text   | Constant string `success`                                 |
| details    | text   | Human-readable status information                         |

### Viewing a generic object

`GET /generic/[id]`

Returns a JSON representation of the requested object if found, or a 404 error otherwise.

| Parameter  | Format | Description                                                 |
| ---------- | ------ | ----------------------------------------------------------- |
| id         | text   | Unique ID of the requested generic object, format `gXY0123` |

| Property   | Format | Description                                                 |
| ---------- | ------ | ----------------------------------------------------------- |
| type       | text   | Constant string `genericobject`                             |
| genericobject | json   | The requested generic object JSON representation         |

### Creating a generic object

`POST /generic`

Adds a new generic object to the database. If the object supplied does not have an ID, a new one will be generated using sequential numbering.

| Parameter  | Format | Description                                               |
| ---------- | ------ | --------------------------------------------------------- |
| data       | text   | JSON-representation of the generic object to be added     |

| Property   | Format | Description                                               |
| ---------- | ------ | --------------------------------------------------------- |
| type       | text   | Constant string `objectID`                                |
| id         | text   | Unique ID of the inserted microorganism, format `gXY123`  |

### Archiving a generic object

`DELETE /generic/[id]`

Mark a generic object as archived without actually deleting any information. Viewing the object data using its unique ID will still work as before.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| id         | text   | Unique ID of the requested object, format `gXY123` |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `success`                          |
| details    | text   | Human-readable status information                  |

### Changing a generic object storage location

`PUT /generic/[id]/storageLocation`

Changes the storage location of the specified generic object to the supplied location.

| Parameter  | Format | Description                                               |
| ---------- | ------ | --------------------------------------------------------- |
| id         | text   | Unique ID of the requested generic object, format `gXY123` |
| newLocation | text  | Canonical name of the storage location, must be unique    |

| Property   | Format | Description                                               |
| ---------- | ------ | --------------------------------------------------------- |
| type       | text   | Constant string `success`                                 |
| details    | text   | Human-readable status information                         |

### Searching the database

`GET /search/[mode]`

Searches the database for matching entries given one of the search mode `description`, `creator`, `id` or `any`. The first three modes search only their respective data fields while `any` searches across the entire database, with some possible exceptions.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| mode       | text   | Search mode, see description above                 |
| query      | text   | Text to search for                                 |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `searchResultList`                 |
| results    | array  | Array of search result objects                     |

The objects in the `results` list have the following properties:

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| id         | text   | Unique ID of the object                            |
| type       | text   | Result type, one of `plasmid`, `microorganism` or `genericobject` |
| createdBy  | text   | Name of the objects's creator                      |
| description | text  | Description of the object                          |


### Configuring the printer

`PUT /print`

Updates or creates the printer used to print labels. In the process, any printer that is already connected will be removed. While only the printer URL and the shared secret are required, a name and location can be set as well.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| url        | text   | URL the printer API can be reached at              |
| authKey    | text   | Shared secret used to authenticate to the printer  |
| name       | text   | Human-readable name of the printer, optional       |
| location   | text   | Human-readable location of the printer, optional   |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `success`                          |
| details    | text   | Human-readable status information                  |

### Querying printer status

`GET /print`

Checks if the currently connected printer (not the device hosting the print server) is turned on and ready to print.

| Property   | Format | Description                                                   |
| ---------- | ------ | ------------------------------------------------------------- |
| type       | text   | Constant string `printerStatus`                               |
| online     | bool   | `true` if the printer is online and ready, `false` otherwise  |

### Printing stickers

`POST /print/[type]/[id]`

Sends a print request for the selected object to the printer. This request may take a long time to complete.
Objects to print may be either plasmids, microorganisms, or generic objects, indicated by the `type` parameter.
If the optional `host` parameter is present, the host value will be printed on the label together with the plasmid selection markers.

| Parameter  | Format | Description                                                       |
| ---------- | ------ | ----------------------------------------------------------------- |
| type       | text   | `p` for plasmids, `m` for microorganisms, `g` for generic objects |
| id         | text   | Unique ID of the requested object, format `pXY123`                |
| host       | text   | Bacterial Host to be printed on label, optional, plasmids only    |
| copies     | int    | Number of labels to print, optional (default 1)                   |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `success`                          |
| details    | text   | Human-readable status information                  |