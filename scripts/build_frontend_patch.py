"""Frontend patch CLI; shared packager handles manifest and runtime exclusions."""
import json
from pathlib import Path
import sys
from scripts.build_patch import frontend_patch
import traceback
try:
    base,candidate,revision,output=sys.argv[1:5]
    patch_id=sys.argv[5] if len(sys.argv)>5 else 'm15-b1'
    manifest=frontend_patch(base,candidate,revision,output,patch_id)
    print(json.dumps({'file_count':manifest['file_count'],'size':(Path(output)/(patch_id+'-patch.zip')).stat().st_size}))
except Exception:
    detail=traceback.format_exc().replace('%','%25').replace('\r','%0D').replace('\n','%0A')
    print('::error::'+detail,flush=True)
    sys.exit(1)
