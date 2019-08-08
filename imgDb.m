classdef imgDb
  % wrapper class for the van Hateren natural image dataset

  % 26/2/2015 - Shaun L. Cloherty <s.cloherty@ieee.org>
  
  properties %(Access = 'Private')
    path = ''; % path to the directory containing the van Hateren image dataset
%     dbVersion = 0.0; % version number

    files = struct('iml',[],'imc',[]); % struct array
    
    imgIds = [];
  end
  
  methods %(Access = 'Private')
    function idx = getImgIdx(db,id), % map id to index
      [~,idx] = intersect(db.imgIds,id);
    end
  end
  
  methods
    function db = imgDb(pth), % constructor
      if ~exist(pth,'dir'),
        error('Database not found at: %s.', pth);
      end
    
      db.path = pth;
    
%       pat = '.*_(?<ver>[\.\d]+).*';
%       db.dbVersion = getfield(regexp(pth,pat,'names'),'ver');
%       if isempty(db.dbVersion),
%         error('Could not determine databse version.');
%       end
                  
      % get list of all image files in the database
      files = rdir(fullfile(db.path,'**','imk*.im*')); % recursive!
%       files = rdir(fullfile(db.path,'**','imk00*.im*')); % recursive!

      pat = ['.*', filesep, 'imk(?<imgId>\d+).(?<fmt>im.?)'];
      
      finfo = arrayfun(@(x) regexp(x.name,pat,'tokens'), files);
      imgIds = cellfun(@(x) str2num(x{1}), finfo, 'UniformOutput', 1);
      imgTyp = cellfun(@(x) lower(x{2}), finfo, 'UniformOutput', 0); % 'iml' = linear, 'imc' = corrected

      [db.imgIds,~,imgIdx] = unique(imgIds); % sorted by image number/id
      
      for idx = 1:length(imgIdx),
        fname = files(idx).name;
        
        db.files(imgIdx(idx)).(imgTyp{idx}) = fname; % 'iml' or 'imc'
      end
      
      % import the image meta data (if available)
      
      % camera settings...
      fnames = {}; % field names of the meta structure
      settings = [];
      
      files = rdir(fullfile(db.path,'**','camerasettings.txt')); % recursive!
      if ~isempty(files),
        if numel(files) > 1,
          error('Multiple camerasettings.txt files found!');
        end
        fdata = importdata(files.name);
        if ~strcmp(fdata.textdata{1},'CAMERA SETTINGS'),
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
      if ~isempty(files),
        if numel(files) > 1,
          error('Multiple imcoffsetlist.txt files found!');
        end
        fdata = importdata(files.name);
        if ~strcmp(fdata.textdata{1},'IMC OFFSET LIST'),
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
      meta = [1:max(db.imgIds)]'; fnames = {};
      
      % append camera settings if available
      if ~isempty(settings),
        [~,ii] = intersect(settings(:,1),meta(:,1));
        
        fnames = {'iso','f','s','scale'};
        meta(settings(ii,1),2:5) = settings(ii,2:5);
      end

      % append offsets if available
      if ~isempty(offsets),
        [~,ii] = intersect(offsets(:,1),meta(:,1));
        
        fnames = [fnames, 'offset'];
        meta(offsets(ii,1),end+1) = offsets(ii,2);
      end
      
      for ii = 1:size(meta,1),
        idx = db.getImgIdx(ii);
        if isempty(idx),
%           warning('Cannot find image %i.', meta(ii));
          continue;
        end
        db.files(idx).id = ii; % this is redundant...
        db.files(idx).meta = cell2struct(arrayfun(@(x) x, meta(ii,2:end),'UniformOutput',0),fnames,2);
      end
    end
    
    function img = getImg(db,id),
      idx = db.getImgIdx(id);

      if isempty(idx),
        img = [];
        return
      end
      
      for i = 1:length(idx),
%         img(i) = Img(db.imgIds(idx(i)));
%         img(i) = Img(db.imgIds{idx(i)});
%         for k = {'iml','imc'},
        for k = {'iml'},
          fname = db.files(idx(i)).(k{1});
          if isempty(fname),
            continue
          end
          try,
%             dta = load(fname,'PassedData');
            fid = fopen(fname, 'rb', 'ieee-be');
            w = 1536; h = 1024;
            img = fread(fid, [w, h], 'uint16')';
            fclose(fid);
          catch,
            warning('imgDb:FileError','Failed to read %s.', fname);
          end

%           % FIXME: move this to the Img constructor...?
% %           n(i).(k{1}) = dta.PassedData;
%           for f = fieldnames(dta.PassedData)',
%             try,
%               spk = SpkFactory.instance().createSpk(lower(f{1}),dta.PassedData.(f{1}));
%             catch,
%               warning('DATABASE:DataError','Could not instantiate Spk object for ''%s''.',lower(f{1}));
%               continue
%             end
%             
%             n(i).(k{1}).(lower(f{1})) = spk;
% 
%             % FIXME: add class abstraction
%             n(i).depth = dta.PassedData.CellInfo.Depth;
%             n(i).trackId = dta.PassedData.CellInfo.TrackNumber;
%           end
        end
      end
    end
  end
  
end
