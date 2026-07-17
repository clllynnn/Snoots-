#!/usr/bin/env python3
"""Generate a review-only Supabase seed from the bundled SQLite workbook export."""

from __future__ import annotations

import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "app" / "Snoots!" / "maps_database.sqlite"
DESTINATION = ROOT / "supabase" / "seed.sql"


FILTER_OPTIONS = [
    ("meetup.leashed_group_walk", "dog_meetup", "牽繩團體散步", "Leashed group walk", 10),
    ("meetup.indoor", "dog_meetup", "室內狗聚", "Indoor dog meetup", 20),
    ("dining.free_movement", "pet_friendly_restaurant", "可自由活動", "Free movement", 10),
    ("dining.floor_allowed", "pet_friendly_restaurant", "可落地", "Dogs on floor", 20),
    ("dining.leash_required", "pet_friendly_restaurant", "需要牽繩", "Leash required", 30),
    ("dining.leash_not_required", "pet_friendly_restaurant", "不需要牽繩", "No leash required", 40),
    ("dining.large_dog", "pet_friendly_restaurant", "大型犬", "Large dog", 50),
    ("dining.medium_dog", "pet_friendly_restaurant", "中型犬", "Medium dog", 60),
    ("dining.small_dog", "pet_friendly_restaurant", "小型犬", "Small dog", 70),
    ("park.off_leash", "pet_friendly_park", "不需要牽繩", "Off leash", 10),
    ("park.natural_grass", "pet_friendly_park", "天然草皮", "Natural grass", 20),
    ("park.safety_facilities", "pet_friendly_park", "安全設施", "Safety facilities", 30),
    ("park.training_facilities", "pet_friendly_park", "訓練設施", "Training facilities", 40),
    ("park.shade_canopy", "pet_friendly_park", "遮陽棚", "Shade canopy", 50),
    ("park.seating", "pet_friendly_park", "休憩座椅", "Seating", 60),
    ("park.all_day", "pet_friendly_park", "全天適合", "Good all day", 70),
    ("park.daytime", "pet_friendly_park", "適合白天", "Good in daytime", 80),
    ("vet.emergency_24h", "animal_hospital", "24 小時急診", "24-hour emergency", 10),
    ("vet.resident_veterinarian", "animal_hospital", "駐診獸醫師", "Resident veterinarian", 20),
    ("vet.oxygen_icu", "animal_hospital", "ICU 氧氣病籠", "Oxygen ICU", 30),
    ("vet.pulse_oximeter", "animal_hospital", "血氧機", "Pulse oximeter", 40),
    ("vet.blood_panel", "animal_hospital", "全套血檢", "Blood panel", 50),
    ("vet.x_ray", "animal_hospital", "X 光", "X-ray", 60),
    ("vet.ultrasound", "animal_hospital", "超音波", "Ultrasound", 70),
]


def sql(value: object | None) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def contains(value: str | None, needle: str) -> bool:
    return needle in (value or "")


def dining_filters(row: sqlite3.Row) -> list[str]:
    result: list[str] = []
    if row["free_roam"] == "可自由活動":
        result.append("dining.free_movement")
    if row["ground_allowed"] == "可落地":
        result.append("dining.floor_allowed")
    if row["leash_required"] == "需要牽繩":
        result.append("dining.leash_required")
    if row["leash_required"] == "不需要牽繩":
        result.append("dining.leash_not_required")
    sizes = row["accepted_dog_size"] or ""
    if "大型犬" in sizes or "大／" in sizes:
        result.append("dining.large_dog")
    if "中型犬" in sizes or "／中／" in sizes:
        result.append("dining.medium_dog")
    if "小型犬" in sizes or sizes.endswith("／小型犬"):
        result.append("dining.small_dog")
    return result


def park_filters(row: sqlite3.Row) -> list[str]:
    candidates = [
        ("park.off_leash", row["leash_required"] == "不需要牽繩"),
        ("park.natural_grass", row["grass_type"] == "天然草皮"),
        ("park.safety_facilities", contains(row["facilities"], "安全性")),
        ("park.training_facilities", contains(row["facilities"], "訓練設施")),
        ("park.shade_canopy", contains(row["shade_or_seating"], "遮陽棚")),
        ("park.seating", contains(row["shade_or_seating"], "座椅")),
        ("park.all_day", row["suitable_time"] == "全天適合"),
        ("park.daytime", row["suitable_time"] == "適合白天"),
    ]
    return [identifier for identifier, matches in candidates if matches]


def hospital_filters(row: sqlite3.Row) -> list[str]:
    candidates = [
        ("vet.emergency_24h", contains(row["emergency_service"], "24小時急診")),
        ("vet.resident_veterinarian", contains(row["emergency_service"], "駐診獸醫師")),
        ("vet.oxygen_icu", contains(row["equipment"], "ICU 氧氣病籠")),
        ("vet.pulse_oximeter", contains(row["equipment"], "血氧機")),
        ("vet.blood_panel", contains(row["testing_equipment"], "全套血檢")),
        ("vet.x_ray", contains(row["testing_equipment"], "X 光")),
        ("vet.ultrasound", contains(row["testing_equipment"], "超音波")),
    ]
    return [identifier for identifier, matches in candidates if matches]


def place_insert(
    place_id: str,
    source_id: int,
    category: str,
    name: str,
    area: str | None,
    address: str | None,
    apple_maps_url: str | None,
    source_url: str,
    policy_summary: str | None,
    dog_access_label: str,
) -> str:
    values = [
        place_id,
        source_id,
        category,
        name,
        area,
        address,
        apple_maps_url,
        source_url,
        policy_summary,
        dog_access_label,
        "needs_reconfirmation",
        False,
    ]
    return (
        "insert into public.places "
        "(id, source_id, category, name, area, address, apple_maps_url, source_url, "
        "policy_summary, dog_access_label, verification_level, published) values ("
        + ", ".join(sql(value) for value in values)
        + ") on conflict (id) do update set "
        "name = excluded.name, area = excluded.area, address = excluded.address, "
        "apple_maps_url = excluded.apple_maps_url, source_url = excluded.source_url, "
        "policy_summary = excluded.policy_summary, dog_access_label = excluded.dog_access_label;"
    )


def main() -> None:
    connection = sqlite3.connect(SOURCE)
    connection.row_factory = sqlite3.Row
    lines = [
        "-- Generated by scripts/generate_supabase_seed.py.",
        "-- Imported records remain unpublished until coordinates and verification dates are reviewed.",
        "begin;",
        "",
    ]

    for option in FILTER_OPTIONS:
        lines.append(
            "insert into public.filter_options "
            "(id, category, title_zh_hant, title_en, display_order) values ("
            + ", ".join(sql(value) for value in option)
            + ") on conflict (id) do update set "
            "category = excluded.category, title_zh_hant = excluded.title_zh_hant, "
            "title_en = excluded.title_en, display_order = excluded.display_order;"
        )

    lines.append("")
    place_filter_rows: list[tuple[str, str, str]] = []

    for row in connection.execute("select * from restaurants order by id"):
        place_id = f"restaurant-{row['id']}"
        lines.append(
            place_insert(
                place_id,
                row["id"],
                "pet_friendly_restaurant",
                row["name"],
                row["district"],
                row["address"],
                row["apple_maps_url"],
                row["source_url"],
                row["policy_summary"],
                "restrictions_apply",
            )
        )
        place_filter_rows.extend((place_id, item, row["source_url"]) for item in dining_filters(row))

    for row in connection.execute("select * from pet_parks order by id"):
        place_id = f"park-{row['id']}"
        lines.append(
            place_insert(
                place_id,
                row["id"],
                "pet_friendly_park",
                row["name"],
                row["city"],
                None,
                row["apple_maps_url"],
                row["source_url"],
                row["official_summary"],
                "outdoor_only",
            )
        )
        place_filter_rows.extend((place_id, item, row["source_url"]) for item in park_filters(row))

    for row in connection.execute("select * from animal_hospitals order by id"):
        place_id = f"hospital-{row['id']}"
        lines.append(
            place_insert(
                place_id,
                row["id"],
                "animal_hospital",
                row["name"],
                row["district"],
                row["district"],
                row["apple_maps_url"],
                row["source_url"],
                row["official_summary"],
                "restrictions_apply",
            )
        )
        place_filter_rows.extend((place_id, item, row["source_url"]) for item in hospital_filters(row))

    lines.append("")
    for place_id, filter_id, source_url in place_filter_rows:
        lines.append(
            "insert into public.place_filters "
            "(place_id, filter_id, source_url, verification_level) values ("
            + ", ".join(sql(value) for value in (place_id, filter_id, source_url, "needs_reconfirmation"))
            + ") on conflict (place_id, filter_id) do update set source_url = excluded.source_url;"
        )

    lines.extend(["", "commit;", ""])
    DESTINATION.write_text("\n".join(lines), encoding="utf-8")
    print(f"Generated {DESTINATION.relative_to(ROOT)} with 35 places and {len(place_filter_rows)} filter links.")


if __name__ == "__main__":
    main()
