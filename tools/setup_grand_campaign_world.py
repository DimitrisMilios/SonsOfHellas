"""
Creates all historical factions, provinces, and armies across the Mediterranean basin.
"""
import os

FACTIONS_DIR = r"c:\Users\dimit\Documents\GitHub\SonsOfHellas\resources\factions"
PROVINCES_DIR = r"c:\Users\dimit\Documents\GitHub\SonsOfHellas\resources\provinces"
ARMIES_DIR = r"c:\Users\dimit\Documents\GitHub\SonsOfHellas\resources\armies"

os.makedirs(FACTIONS_DIR, exist_ok=True)
os.makedirs(PROVINCES_DIR, exist_ok=True)
os.makedirs(ARMIES_DIR, exist_ok=True)

# 1. Factions
factions_data = [
    ("sparta", "Sparta (Lacedaemon)", "Color(0.85, 0.15, 0.15, 1.0)", True, 1200, 3200),
    ("athens", "Athens (Delian League)", "Color(0.15, 0.45, 0.85, 1.0)", False, 1500, 3500),
    ("thebes", "Thebes (Boeotian League)", "Color(0.85, 0.65, 0.12, 1.0)", False, 1000, 2800),
    ("corinth", "Corinth", "Color(0.15, 0.58, 0.62, 1.0)", False, 1400, 3000),
    ("macedon", "Kingdom of Macedon", "Color(0.45, 0.15, 0.60, 1.0)", False, 1100, 3000),
    ("thessaly", "Thessalian League", "Color(0.35, 0.65, 0.35, 1.0)", False, 900, 2500),
    ("thrace", "Thracian Tribes", "Color(0.60, 0.40, 0.20, 1.0)", False, 800, 2400),
    ("knossos", "Cretan Cities", "Color(0.20, 0.70, 0.70, 1.0)", False, 900, 2600),
    ("rhodes", "Rhodes", "Color(0.70, 0.50, 0.20, 1.0)", False, 1100, 2800),
    ("rome", "Roman Republic", "Color(0.75, 0.10, 0.12, 1.0)", False, 1300, 3200),
    ("carthage", "Carthaginian Empire", "Color(0.55, 0.15, 0.50, 1.0)", False, 1600, 3600),
    ("syracuse", "Syracuse", "Color(0.25, 0.60, 0.75, 1.0)", False, 1000, 2800),
    ("egypt", "Ptolemaic Egypt", "Color(0.10, 0.60, 0.65, 1.0)", False, 1800, 3800),
    ("seleucid", "Seleucid Empire", "Color(0.85, 0.45, 0.15, 1.0)", False, 1700, 3700),
    ("pontus", "Kingdom of Pontus", "Color(0.25, 0.25, 0.55, 1.0)", False, 1000, 2800),
]

for fid, name, color, is_player, treasury, purse in factions_data:
    content = f"""[gd_resource type="Resource" script_class="FactionData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/FactionData.gd" id="1_faction"]

[resource]
script = ExtResource("1_faction")
faction_id = "{fid}"
faction_name = "{name}"
faction_color = {color}
is_player = {"true" if is_player else "false"}
treasury = {treasury}
base_purse = {purse}
"""
    with open(os.path.join(FACTIONS_DIR, f"{fid}.tres"), "w", encoding="utf-8") as f:
        f.write(content)

# 2. Provinces
provinces_data = [
    # id, name, owner, x, y, adj, tier, wealth
    ("sparta", "Sparta", "sparta", 1217.2, 578.7, ["corinth", "knossos"], 3, 2200.0),
    ("athens", "Athens", "athens", 1271.0, 530.5, ["corinth", "thebes", "rhodos", "knossos"], 4, 3500.0),
    ("thebes", "Thebes", "thebes", 1254.5, 512.5, ["athens", "corinth", "delphi", "larissa"], 3, 2400.0),
    ("corinth", "Corinth", "corinth", 1238.3, 533.2, ["sparta", "athens", "thebes", "delphi"], 3, 2800.0),
    ("delphi", "Delphi", "thebes", 1220.5, 504.1, ["corinth", "thebes", "larissa"], 2, 1600.0),
    ("larissa", "Larissa", "thessaly", 1216.8, 442.6, ["delphi", "thebes", "pella"], 2, 1800.0),
    ("pella", "Pella", "macedon", 1221.4, 383.3, ["larissa", "byzantium"], 3, 2600.0),
    ("byzantium", "Byzantium", "thrace", 1488.2, 370.1, ["pella", "pergamum", "sinope"], 3, 3000.0),
    ("knossos", "Knossos", "knossos", 1330.6, 673.0, ["sparta", "athens", "rhodos", "alexandria"], 2, 2000.0),
    ("rhodos", "Rhodes", "rhodes", 1457.2, 612.6, ["athens", "knossos", "ephesus"], 2, 2400.0),
    ("roma", "Roma", "rome", 806.4, 323.5, ["tarentum", "massalia"], 4, 3600.0),
    ("tarentum", "Tarentum", "rome", 1002.9, 398.7, ["roma", "syracuse"], 2, 2000.0),
    ("syracuse", "Syracuse", "syracuse", 921.8, 578.7, ["tarentum", "carthago"], 3, 2600.0),
    ("massalia", "Massalia", "rome", 511.8, 248.9, ["roma"], 2, 1800.0),
    ("carthago", "Carthago", "carthage", 716.6, 590.4, ["syracuse", "cyrene"], 4, 3800.0),
    ("cyrene", "Cyrene", "carthage", 1193.6, 803.7, ["carthago", "alexandria"], 2, 2000.0),
    ("alexandria", "Alexandria", "egypt", 1527.1, 889.5, ["knossos", "cyrene", "memphis", "tyre"], 4, 4000.0),
    ("memphis", "Memphis", "egypt", 1582.5, 961.0, ["alexandria", "jerusalem"], 3, 3000.0),
    ("ephesus", "Ephesus", "seleucid", 1420.8, 532.7, ["rhodos", "pergamum", "antioch"], 3, 2700.0),
    ("pergamum", "Pergamum", "seleucid", 1414.2, 470.2, ["byzantium", "ephesus", "sinope"], 3, 2600.0),
    ("sinope", "Sinope", "pontus", 1743.9, 316.6, ["byzantium", "pergamum", "antioch"], 2, 2100.0),
    ("antioch", "Antioch", "seleucid", 1785.7, 624.8, ["ephesus", "sinope", "tyre"], 4, 3500.0),
    ("tyre", "Tyre", "seleucid", 1745.6, 779.9, ["antioch", "alexandria", "jerusalem"], 3, 2800.0),
    ("jerusalem", "Jerusalem", "egypt", 1746.4, 859.3, ["tyre", "memphis"], 2, 2200.0),
]

for pid, name, owner, x, y, adj, tier, wealth in provinces_data:
    adj_str = ", ".join([f'"{a}"' for a in adj])
    content = f"""[gd_resource type="Resource" script_class="ProvinceData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/ProvinceData.gd" id="1_prov"]

[resource]
script = ExtResource("1_prov")
province_id = "{pid}"
province_name = "{name}"
owner_faction_id = "{owner}"
map_position = Vector2({x}, {y})
adjacent_province_ids = [{adj_str}]
settlement_level = {tier}
settlement_tier = {tier}
region_wealth = {wealth}
public_order = 100.0
"""
    with open(os.path.join(PROVINCES_DIR, f"{pid}.tres"), "w", encoding="utf-8") as f:
        f.write(content)

print(f"Generated {len(factions_data)} factions and {len(provinces_data)} provinces successfully!")
