import json, sys
from stitch import call
PID = "12357068339961859333"
BRAND = ("Brand: 'Talk It Out', a workplace group-chat app where messages can be anonymous, an AI rewrites "
         "them in a calm tone, and a group controller reviews before anyone sees them. Visual style: bold "
         "monochrome. Canvas light cream #FCFAF6, cards white with 18-20px radius and a hairline border #E7E3DC, "
         "text near-black #09090B, secondary #71717A. Top of top-level screens is a black hero header with "
         "rounded bottom corners and a large white title. Primary buttons are black pills, secondary are white "
         "with a black outline. Font Inter. Icons: thin line icons (Phosphor style). No gradients, no purple, "
         "no emoji. Mobile, 390 wide. ")
name, prompt = sys.argv[1], sys.argv[2]
ds = sys.argv[3] if len(sys.argv) > 3 else None
args = {"projectId": PID, "prompt": BRAND + prompt, "deviceType": "MOBILE", "modelId": "GEMINI_3_8_FLASH"}
if ds:
    args["designSystem"] = ds
res = call("generate_screen_from_text", args, timeout=900)
open(f"{name}.json", "w").write(json.dumps(res, indent=1))
print(json.dumps(res)[:1500])
