classdef vanhateren < imgDb
  % Wrapper around the van Hateren natural image dataset.
  %
  % See http://bethgelab.org/datasets/vanhateren/ for details.
  
  % 2015-02-26 - Shaun L. Cloherty <s.cloherty@ieee.org>
  
  methods
    function db = vanhateren(pth,varargin) % constructor
      % call parent constructor
      db = db@imgDb(pth,varargin{:});
      
      % get list of all image files in the database
      files = rdir(fullfile(db.path,'**','imk*.im*')); % recursive!

      pat = ['.*', filesep, 'imk(?<imgId>\d+).(?<fmt>im.?)'];
      
      finfo = arrayfun(@(x) regexp(x.name,pat,'tokens'), files);
      imgIds = cellfun(@(x) str2num(x{1}), finfo, 'UniformOutput', 1);
      imgTyp = cellfun(@(x) lower(x{2}), finfo, 'UniformOutput', 0); % 'iml' = linear, 'imc' = corrected

      [imgIds,~,imgIdx] = unique(imgIds); % sorted by image number/id
      
      for idx = 1:length(imgIds)
        key = imgIdx(idx);
        
        fname = files(idx).name;
        
        img = struct('key',key,imgTyp{idx},fname); % imgTyp is 'iml' or 'imc'
        
        db.info(key) = img;
      end
      
      % db.info contains structs with fields:
      %
      %   .key - database key/image id (redundant?)
      %   .iml - full path to the .iml file
      %   .imc - full path to the .imc file
      
      % import the image meta data (if available)
      
      % camera settings...
      fnames = {}; % field names of the meta structure
      settings = [];
      
      files = rdir(fullfile(db.path,'**','camerasettings.txt')); % recursive!
      if ~isempty(files)
        if numel(files) > 1
          error('Multiple camerasettings.txt files found!');
        end
        fdata = importdata(files.name);
        if ~strcmp(fdata.textdata{1},'CAMERA SETTINGS')
          error('Error reading camerasettings.txt');
        end
      
        % colmns in settings are as follows:
        %   1: image number (imgId),
        %   2: ISO setting (i.e., electronic equivalent),
        %   3: aperture;
        %   4: reciprocal shutter time (1/s),
        %   5: factor for converting pixel values to luminance (cd/m2;
        %        i.e., luminance = factor*pixel value)
%         fnames = {'iso','f','s','scale'};
        settings = fdata.data;
        clear files fdata
      end
      
      % pixel value offsets
      offsets = [];
      
      files = rdir(fullfile(db.path,'**','imcoffsetlist.txt')); % recursive!
      if ~isempty(files)
        if numel(files) > 1
          error('Multiple imcoffsetlist.txt files found!');
        end
        fdata = importdata(files.name);
        if ~strcmp(fdata.textdata{1},'IMC OFFSET LIST')
          error('Error reading imcoffsetlist.txt');
        end
      
        % columns in offsets are as follows:
        %   1: image number (imgId)
        %   2: pixel value offset
        %
        % the offsets have been added to all pixels in the corresponding
        % 'calibrated' (imc) images when deconvolution of the linear (iml)
        % image with the point spread function of the imaging optics resulted
        % in -ve pixel values.
%         fnames = [fnames,'offset'];
        offsets = fdata.data;
        clear files fdata
      end
     
      % each row of meta contains the camera settings and/or offset for a
      % single image, indexed by image id
      meta = [1:max(imgIds)]'; fnames = {};
      
      % append camera settings if available
      if ~isempty(settings)
        [~,ii] = intersect(settings(:,1),meta(:,1));
        
        fnames = {'iso','f','s','scale'};
        meta(settings(ii,1),2:5) = settings(ii,2:5);
      end

      % append offsets if available
      if ~isempty(offsets)
        [~,ii] = intersect(offsets(:,1),meta(:,1));
        
        fnames = [fnames, 'offset'];
        meta(offsets(ii,1),end+1) = offsets(ii,2);
      end
      
      for ii = 1:size(meta,1)
%         idx = db.getImgIdx(ii);
%         if isempty(idx)
% %           warning('Cannot find image %i.', meta(ii));
%           continue;
%         end
%         db.files(idx).key = ii; % this is redundant...

        key = imgIdx(ii);
        if ~db.info.isKey(key)
          warning('Cannot find image %i.', meta(ii));
          continue;
        end

        db.info(key).meta = cell2struct(arrayfun(@(x) x, meta(ii,2:end),'UniformOutput',0),fnames,2);
      end

      % each entry in db.info is a struct with fields:
      %
      %   .key - database key/image id (redundant?)
      %   .iml - full path to the .iml file
      %   .imk - full path to the .imk
      %   .meta - struct of image meta data
      %
      % the .meta sub-struct has fields
      %
      %   .iso - ISO setting (i.e., electronic equivalent)
      %   .f - aperture (F-number?)
      %   .s - reciprocal shutter time (1/s)
      %   .scale - factor for converting pixel values to luminance (cd/m2)
      %   .offset - pixel value offset for the imc image (if applicable)
    end
    
    function img = getImg(db,key,varargin)
      % Returns the image corresponding to the supplied database key.
      %
      % Usage:
      %
      %   img = db.getImg(key[,corrected])
      %
      % The optional argument corrected is true or false. If false, or 
      % omitted, getImg() returns the linear image (i.e., corrected = false).
      
      if ~db.info.isKey(key)
        img = [];
        return
      end

      type = 'iml'; % default: linear
      if (nargin > 2) & varargin{1}
        type = 'imc'; % corrected
      end
      
      for ii = 1:length(key)
        fname = db.info(key(ii)).(type);
        
%         if isempty(fname)
%           continue
%         end

        try
          fid = fopen(fname,'rb','ieee-be');
          w = 1536; h = 1024;
          img{ii} = fread(fid,[w,h],'uint16')';
          fclose(fid);
        catch
          warning('Failed to read %s.',fname);
        end
      end
      
      if numel(img) == 1
        img = cell2mat(img);
      end
    end
    
  end % methods
  
end % classdef