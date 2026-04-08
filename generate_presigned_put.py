#!/usr/bin/env python3
import argparse
import json
import os
import sys

import boto3
from botocore.config import Config
from dotenv import load_dotenv


def build_s3_client():
    load_dotenv()

    region = os.getenv("AWS_REGION")
    bucket = os.getenv("S3_BUCKET")
    endpoint_url = os.getenv("S3_ENDPOINT_URL") or None

    if not region:
        raise ValueError("AWS_REGION is required")
    if not bucket:
        raise ValueError("S3_BUCKET is required")

    client = boto3.client(
        "s3",
        region_name=region,
        endpoint_url=endpoint_url,
        config=Config(signature_version="s3v4"),
    )
    return client, bucket


def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate a presigned PUT URL for S3-compatible storage"
    )
    parser.add_argument("--key", required=True, help="Object key in the bucket")
    parser.add_argument(
        "--content-type",
        required=True,
        help="Content-Type that must be used in the PUT request",
    )
    parser.add_argument(
        "--expires",
        type=int,
        default=3600,
        help="Expiration time in seconds (default: 3600)",
    )
    parser.add_argument(
        "--acl",
        default=None,
        help="Optional ACL, e.g. public-read (only if your provider/bucket policy allows it)",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    try:
        s3, bucket = build_s3_client()

        params = {
            "Bucket": bucket,
            "Key": args.key,
            "ContentType": args.content_type,
        }

        if args.acl:
            params["ACL"] = args.acl

        url = s3.generate_presigned_url(
            ClientMethod="put_object",
            Params=params,
            ExpiresIn=args.expires,
            HttpMethod="PUT",
        )

        result = {
            "bucket": bucket,
            "key": args.key,
            "content_type": args.content_type,
            "expires_in": args.expires,
            "url": url,
        }

        print(json.dumps(result, ensure_ascii=False, indent=2))
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
