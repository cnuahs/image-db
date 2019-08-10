classdef geisler < imgdb.db
  % Wrapper around the UT natural image dataset(s).
  %
  % See http://natural-scenes.cps.utexas.edu/db.shtml for details.
  
  % 2019-08-08 - Shaun L. Cloherty <s.cloherty@ieee.org>
    
  properties (Constant)
    colorModes = {'RAW','XYZ','XYY','LUM','RGB'};
  end
  
  methods
    function db = geisler(pth,varargin) % constructor
      % call parent constructor
      db = db@imgdb.db(pth,varargin{:});
            
      % get list of all image (.ppm - portable pixmap) files in the database
      files = rdir(fullfile(db.path,'**','*.ppm')); % recursive!

      [~,imgIds,~] = arrayfun(@(x) fileparts(x.name),files,'UniformOutput',false);

      [imgIds,~,imgIdx] = unique(imgIds); % sorted by image number/id
      
      for ii = 1:length(imgIds)
        key = imgIdx(ii); % unique key in db.info()
        
        fname = files(ii).name; % full path to the .ppm file

        img = struct('key',key,'ppm',fname,'meta',struct());
        
        % fetch the image meta data (if available)
        [~,name,ext] = fileparts(fname);
        exif = rdir(fullfile(pth,'**',[name, '.exif'])); % recursive!
          
        if ~isempty(exif)          
          fid = fopen(exif.name,'r');
          while ~feof(fid)
            txt = fgetl(fid);
      
            pat = '(?<field>[ a-zA-Z0-9\-/]*)\s*:\s+(?<value>.*)';
            tokens = regexp(txt,pat,'names');
      
            % replace spaces etc. with '_'
            tokens.field = regexprep(strip(tokens.field),'[\s-/]+','_');
            
            meta.(tokens.field) = tokens.value;
          end
          fclose(fid);
        
          img.exif = exif.name;          
          img.meta = meta;
        end
        
        db.info(key) = img;
      end
      
      % each entry in db.info is a struct with fields:
      %
      %   .key - database key/image id (redundant?)
      %   .ppm - full path to the .ppm file
      %   .meta - struct of image meta data
      %
      % the .meta sub-struct has many many fields. The ones you probably
      % care most about are:
      %
      %   .F_Number - aperturs, and
      %   .Shutter_Speed - exposure time (in fraction of a second, e.g., '1/400')
    end
    
    function img = getImg(db,key,varargin)
      % Load image(s) for the given database key(s).
      img = arrayfun(@(x) imgdb.geisler.load(db.info(x),varargin{:}),key,'UniformOutput',false);
      
      if numel(img) == 1
        img = cell2mat(img);
      end
    end
  end
    
  methods (Static)
    function img = load(rec,varargin)
      % Load image(s) for the given database record(s).
      %
      %   img = geisler.load(rec[,...])
      %
      % optional name-value arguments:
      %
      %   colorMode - desired color mode, must be one of 'raw','XYZ','xyY',
      %               'lum' or 'rgb' (default: 'lum', scalar/grayscale image)
      
      % parse arguments
      p = inputParser();
      p.addParameter('colorMode','lum',@(x) ismember(upper(x),imgdb.geisler.colorModes)); % scalar (grayscale) image

      p.parse(varargin{:});
      args = p.Results;
      %

      colorMode = find(ismember(imgdb.geisler.colorModes,upper(args.colorMode)));
            
      for ii = 1:length(rec)
        fname = rec(ii).ppm; % full filename of the .ppm file

        try
          raw = double(imread(fname,'ppm'))./(2^16-1); % TODO: should get bit depth from imfinfo()
        catch
          warning('Failed to read %s.',fname);
        end
        
        if colorMode == 1 % raw
          img{ii} = raw;
          continue
        end

        assert(isfield(rec(ii),'meta'), ...
          'No meta data available. Cannot convert to the requested color mode.');
        
        % get exposure parameters (aperture and exposure time)...
        f = str2double(rec(ii).meta.F_Number);
        T = eval(rec(ii).meta.Shutter_Speed); % <-- urgh, nasty!

        % convert to CIE XYZ, and from there to the requested colorspace
        xyz = imgdb.geisler.raw2xyz(raw,f,T);
        
        switch colorMode
          case 2 % XYZ
            img{ii} = xyz;
          case 3 % xyY (aka xyL)
%             img{ii} = imgdb.geisler.raw2xyy(raw,f,T);
            img{ii} = imgdb.geisler.xyz2xyy(xyz);
          case 4 % lum
            img{ii} = xyz(:,:,2); % Y in XYZ is luminance
          case 5 % RGB (aka sRGB)
%             img{ii} = imgdb.geisler.raw2rgb(raw,f,T);
            img{ii} = imgdb.geisler.xyz2rgb(xyz);
          otherwise
            error('Unrecognized color mode %s.');
        end
        
        % clip...?
        img{ii} = min(max(img{ii},0.0),1.0);
      end
      
      if numel(img) == 1
        img = cell2mat(img);
      end
    end
          
    function xyz = raw2xyz(raw,f,T)
      % convert the raw RGB values from the database to CIE XYZ
      % tristimulus values.
      
      % given the aperture (f) and exposure time (T, in seconds), compute
      % the conversion matrix... this is taken from the camera calibration
      % notes at
      %
      %   http://natural-scenes.cps.utexas.edu/Camera_Calibration_Notes.pdf
      %
      % and, I believe, assumes color matching functions as per Judd (1951)
      % and Vos (1978).
      c = (683*(f^2)/T) * [6.155e-9,   1.376e-9,  9.558e-10; ...
                           3.174e-9,   7.723e-9, -1.152e-9; ...
                           1.819e-10, -1.300e-9,  9.951e-9];
      
      dims = size(raw);
      xyz = reshape(c*reshape(raw,3,[]),dims);
      
      maxY = [0, 1, 0] * c*ones([3,1]); % <-- sensor saturation produces Y = 1?
      xyz = xyz./maxY;
    end
    
    function xyY = raw2xyy(raw,f,T)
      % converts the raw RGB values from the database to CIE xyY (aka xyL).
      xyz = imgdb.geisler.raw2xyz(raw,f,T);
      
      xyY = imgdb.geisler.xyz2xyy(xyz);
    end
    
    function xyY = xyz2xyy(xyz)
      % convert CIE XYZ tristimulus valuse to CIE xyY.
      X = xyz(:,:,1);
      Y = xyz(:,:,2);
      Z = xyz(:,:,3);
      
      xyY(:,:,1) = X ./ (X + Y + Z); % x
      xyY(:,:,2) = Y ./ (X + Y + Z); % y
      xyY(:,:,3) = Y; % Y <-- luminance
    end
    
    function rgb = raw2rgb(raw,f,T)
      % convert the raw RGB values from the database to sRGB.
      xyz = imgdb.geisler.raw2xyz(raw,f,T);
      
      rgb = imgdb.geisler.xyz2rgb(xyz);
    end
    
    function rgb = xyz2rgb(xyz)
      % convert CIE XYZ tristimulus values to sRGB.
      
      % conversion matrix to [linear] sRGB (D65 reference white)
      c = [ 3.2404542, -1.5371385, -0.4985314; ...
           -0.9692660,  1.8760108,  0.0415560; ...
            0.0556434, -0.2040259,  1.0572251];      
          
      dims = size(xyz);
      rgb = reshape(c*reshape(xyz,3,[]),dims);
    end
  end % static methods
  
end % classdef