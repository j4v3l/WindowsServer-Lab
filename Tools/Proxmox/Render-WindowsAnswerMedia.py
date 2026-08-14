#!/usr/bin/env python3
"""Render nonpersistent Windows answer-media files from runtime build inputs."""

from __future__ import annotations

import argparse
import ipaddress
import os
import re
import stat
import xml.etree.ElementTree as ET
from pathlib import Path
from xml.sax.saxutils import escape


OS_SETTINGS = {
    # Microsoft-published KMS client setup keys select the intended edition
    # during unattended installation. They do not provide an activation
    # entitlement; activation remains a separate operator workflow.
    "server-2025": ("/IMAGE/INDEX", "2", "2k25", "TVRH6-WHNXV-R9WG3-9XRFY-MY832"),
    "windows-11": ("/IMAGE/NAME", "Windows 11 Education", "w11", "NW6C2-QMPVW-D7KKK-3GKT6-VCFB2"),
}


def required_environment(name: str) -> str:
    value = os.environ.get(name, "")
    if not value:
        raise SystemExit(f"Required runtime environment value is missing: {name}")
    return value


def write_private(path: Path, content: str) -> None:
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, stat.S_IRUSR | stat.S_IWUSR)
    with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
        stream.write(content)


def replace_all(template: str, replacements: dict[str, str]) -> str:
    rendered = template
    for token, value in replacements.items():
        if token not in rendered:
            raise SystemExit(f"Expected template token is missing: {token}")
        rendered = rendered.replace(token, value)
    return rendered


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--os", choices=sorted(OS_SETTINGS), required=True)
    parser.add_argument("--template-directory", type=Path, required=True)
    parser.add_argument("--output-directory", type=Path, required=True)
    arguments = parser.parse_args()

    if not arguments.output_directory.is_dir():
        raise SystemExit("Output directory must already exist")

    windows_password = required_environment("PKR_VAR_windows_password")
    cloudbase_sha256 = required_environment("PKR_VAR_cloudbase_msi_sha256")
    osconfig_sha256 = required_environment("PKR_VAR_osconfig_nupkg_sha256")
    osconfig_version = required_environment("PKR_VAR_osconfig_version")
    qemu_agent_sha256 = required_environment("WSLAB_QEMU_AGENT_MSI_SHA256")
    build_ipv4_address = required_environment("WSLAB_BUILD_IPV4_ADDRESS")
    build_ipv4_prefix_length = required_environment("WSLAB_BUILD_IPV4_PREFIX_LENGTH")
    build_ipv4_gateway = required_environment("WSLAB_BUILD_IPV4_GATEWAY")
    build_dns_servers = required_environment("WSLAB_BUILD_DNS_SERVERS").split(",")
    selector_key, selector_value, driver_path, default_setup_key = OS_SETTINGS[arguments.os]
    windows_setup_key = os.environ.get("PKR_VAR_windows_setup_key", default_setup_key)
    if not re.fullmatch(r"[A-Fa-f0-9]{64}", cloudbase_sha256):
        raise SystemExit("Cloudbase-Init digest must be SHA-256")
    if not re.fullmatch(r"[A-Fa-f0-9]{64}", qemu_agent_sha256):
        raise SystemExit("QEMU Guest Agent digest must be SHA-256")
    if not re.fullmatch(r"[A-Fa-f0-9]{64}", osconfig_sha256):
        raise SystemExit("Microsoft.OSConfig digest must be SHA-256")
    if not re.fullmatch(r"\d+\.\d+\.\d+", osconfig_version):
        raise SystemExit("Microsoft.OSConfig version must use semantic version format")
    try:
        ipaddress.IPv4Address(build_ipv4_address)
        ipaddress.IPv4Address(build_ipv4_gateway)
        prefix_length = int(build_ipv4_prefix_length)
        if prefix_length not in range(1, 33):
            raise ValueError
        for dns_server in build_dns_servers:
            ipaddress.IPv4Address(dns_server)
    except ValueError as error:
        raise SystemExit("Template build network values must be valid IPv4 settings") from error
    if not re.fullmatch(r"[A-Za-z0-9]{5}(?:-[A-Za-z0-9]{5}){4}", windows_setup_key):
        raise SystemExit("Windows setup key has an invalid format")
    product_key_block = (
        "<ProductKey><Key>"
        + escape(windows_setup_key)
        + "</Key><WillShowUI>Never</WillShowUI></ProductKey>"
    )

    answer_template = (arguments.template_directory / "Autounattend.xml.pkrtpl").read_text(encoding="utf-8")
    answer = replace_all(
        answer_template,
        {
            "${image_selector_key}": escape(selector_key),
            "${image_selector_value}": escape(selector_value),
            "${windows_password}": escape(windows_password),
            "${driver_path}": escape(driver_path),
            "${product_key_block}": product_key_block,
        },
    )
    try:
        ET.fromstring(answer)
    except ET.ParseError as error:
        raise SystemExit(f"Rendered answer XML is invalid: {error}") from error

    bootstrap_template = (arguments.template_directory / "bootstrap.ps1.pkrtpl").read_text(encoding="utf-8")
    bootstrap = replace_all(
        bootstrap_template,
        {
            "${os_type}": arguments.os,
            "${cloudbase_msi_sha256}": cloudbase_sha256,
            "${qemu_agent_msi_sha256}": qemu_agent_sha256,
            "${osconfig_nupkg_sha256}": osconfig_sha256,
            "${osconfig_version}": osconfig_version,
            "${build_ipv4_address}": build_ipv4_address,
            "${build_ipv4_prefix_length}": str(prefix_length),
            "${build_ipv4_gateway}": build_ipv4_gateway,
            "${build_dns_servers}": ", ".join(f"'{server}'" for server in build_dns_servers),
            "${windows_password_ps}": windows_password.replace("'", "''"),
        },
    )

    write_private(arguments.output_directory / "Autounattend.xml", answer)
    write_private(arguments.output_directory / "bootstrap.ps1", bootstrap)


if __name__ == "__main__":
    main()
