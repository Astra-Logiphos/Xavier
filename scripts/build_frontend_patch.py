"""Frontend patch CLI; shared packager handles manifest and runtime exclusions."""
import json
from pathlib import Path
import sys
from scripts.build_patch import frontend_patch
base,candidate,revision,output=sys.argv[1:]
manifest=frontend_patch(base,candidate,revision,output)
print(json.dumps({'file_count':manifest['file_count'],'size':(Path(output)/'m15-b1-patch.zip').stat().st_size}))
