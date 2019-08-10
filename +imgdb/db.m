classdef (Abstract) db
  % Abstract 'database' wrapper for image datasets.

  % 2015-02-26 - Shaun L. Cloherty <s.cloherty@ieee.org>
  
  properties (GetAccess = public, SetAccess = protected)
    path; % path(s) containing the images and metadata

    info; % info for each image in the database
  end
  
  properties (Dependent)
    keys;
    imgs;
  end
  
  methods    
    function v = get.keys(db)
      v = db.info.keys();
    end
    
    function v = get.imgs(db)
      v = db.info.values();
    end
  end
    
  methods
    function db = db(varargin) % constructor
      % create empty database
      db.path = {};
      db.info = containers.Map('KeyType','char','ValueType','any');

      if nargin < 1
        return
      end

      % varargin contains one or more paths to add
      for ii = 1:nargin
        db = db.add(varargin{ii});
      end
    end
  end % methods
    
  methods (Abstract)
    db = add(db,pth); % add images in pth to the database
    
    img = getImg(db,key,varargin); % retrieve an image (by key) from disk
  end
  
end
