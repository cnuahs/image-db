# img-db

Matlab wrappers for various image databases.

I created this primarily as a wrapper around two natural image datasets (the van Hateren natural image dataset, and Bill Geisler's natural scene collections; links below). However, it could be used for any collection of image files you want to index and retrieve from disk.

Example usage, assuming you have downloaded one of Bill Geisler's natural scene collections (link below):
```
% create the database (i.e., index the files on disk,
% parse the .exif files etc.)
db = imgdb.geisler('~/path/to/image/set1');

% select a random image/key from the dataset
key = cell2mat(randsample(db.keys,1));

% retrieve the image
img = db.getImg(key{1});

% show it...
figure; imshow(img);

% the image, img, returned above will be a scalar/grayscale
% image. This is the default behaviour for the @geisler database
% class but the images in the UT scene collections are "raw"
% colour (RGB) images. Depending on your needs, the @geisler
% database class can also retrieve the original raw image data,
% e.g.,
raw = db.getImg(key,'colorMode','raw');

% or, alternatively, can perform various colour space conversions
% on retrieval, e.g.,
xyz = db.getImg(key,'colorMode','xyz');

% or, converted to sRGB...
rgb = db.getImg(key,'colorMode','rgb');
figure; imshow(rgb);

% these conversions take into account the camera sensitiviy
% profiles, calibration parameters etc., but the images remain
% 'linear', no gamma correction is applied.
```

# Notes
1. You can add multiple paths/directories to the database either by passing them to the constructor:
```
db = imgdb.geisler('~/path/to/image/set1','~/path/to/image/set2');
```
or explicitly calling the .add() method:
```
db = imgdb.geisler('~/path/to/image/set1');
db = db.add('~/path/to/image/set2');
```
2. There is currently nothing stopping you from adding the same path to the database multiple times. If a record already exists in the database for a given image/key (e.g., because you've already added a given path), it will be silently overwritten.

3. To make use of Bill Geisler's natural scene collections, download a set of image files *and* the corresponding EXIF meta data. These are available in separate .zip files for each collection/image set on the site linked below. The meta data is required for the colour space conversions to work. Unzip both files in a directory of your choice and add that path to the @geisler database, either via the class constructor or using the .add() method.

# Links
1. The van Hateren natural image dataset is available [here](http://bethgelab.org/datasets/vanhateren/).

2. Bill Geisler's natural image database is available as several scene collections, with extensive meta data and camera calibration notes [here](http://natural-scenes.cps.utexas.edu/db.shtml).
