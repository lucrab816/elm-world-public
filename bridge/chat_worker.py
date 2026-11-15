"""One user-initiated request via the official subscription CLI, no API fallback."""
import argparse
import json
from pathlib import Path
import signal
from subscription_probe import run_probe


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--cancel',type=Path,required=True)
    parser.add_argument('--cli',required=True)
    args = parser.parse_args()
    def cancel(*_):
        args.cancel.touch()
    signal.signal(signal.SIGTERM,cancel)
    signal.signal(signal.SIGINT,cancel)
    result = {'status':'invalid_request','source':'local_fallback'}
    try:
        if args.input.stat().st_size>16384:
            raise ValueError('large input')
        data = json.loads(args.input.read_text())
        if not isinstance(data,dict) or not isinstance(data.get('message'),str) or not 1<=len(data['message'].strip())<=240:
            raise ValueError('invalid message')
        if data.get("kind","chat") not in ("chat","decision","plant_decision","self_arrangement","life_plan"):
            raise ValueError("invalid request kind")
        if not isinstance(data.get('context'),dict) or len(json.dumps(data,ensure_ascii=False))>8000:
            raise ValueError('invalid context')
        if args.cancel.exists():
            result = {'status':'cancelled','source':'local_fallback'}
        else:
            attachment = args.input.with_name("attachment.jpg")
            if not (data.get("kind") == "life_plan" and data["context"].get("letter") and attachment.is_file()):
                attachment = None
            result = run_probe(dict(data,_chat=True),60,cancel_file=args.cancel,cli_path=args.cli,image_path=attachment)
    except (OSError,ValueError,TypeError):
        pass
    temporary = args.output.with_suffix('.tmp')
    temporary.write_text(json.dumps(result,ensure_ascii=False))
    temporary.replace(args.output)

if __name__=='__main__':
    main()
