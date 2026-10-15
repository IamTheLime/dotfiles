#!/usr/bin/env python3

import argparse
import json
import secrets
import string


def main():
    parser = argparse.ArgumentParser(description="Generate design exploration seeds.")
    parser.add_argument("--count", type=int, choices=range(1, 13), default=3)
    args = parser.parse_args()
    alphabet = string.ascii_letters + string.digits
    concepts = [
        {
            "id": f"concept-{index + 1}",
            "seed": "".join(secrets.choice(alphabet) for _ in range(128)),
        }
        for index in range(args.count)
    ]
    print(json.dumps({"generator": "python.secrets", "concepts": concepts}, indent=2))


if __name__ == "__main__":
    main()
