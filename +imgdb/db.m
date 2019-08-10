classdef (Abstract) db
  % Abstract 'database' wrapper for image datasets.

  % 2015-02-26 - Shaun L. Cloherty <s.cloherty@ieee.org>
  
  properties (GetAccess = public, SetAccess = protected)
    path = ''; % path to the directory containing the images and metadata

    info = containers.Map('KeyType','double','ValueType','any'); % info for each image in the database
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
    function db = db(pth) % constructor
      if ~exist(pth,'dir')
        error('Database not found at: %s.', pth);
      end
    
      db.path = pth; 
    end
  end
    
  methods (Abstract)
    img = getImg(db,key,varargin)
  end
  
end
