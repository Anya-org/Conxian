import re

with open('Clarinet.toml', 'r') as f:
    content = f.read()

# Separate contract blocks from the rest
contract_blocks = re.findall(r'\[contracts\.[^\]]+\].*?(?=\n\[contracts\.|\Z)', content, flags=re.DOTALL)

# Reconstruct TOML
new_content = """[project]
name = "Conxian"
authors = []
description = "Conxian Protocol"
telemetry = false
cache_dir = "./.cache"
requirements = []

[simnet]
mnemonic = "cute bird surprise boring old news cake design aisle helmet choose tree"
epoch = "3.0"

[accounts]
deployer = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"
wallet_1 = "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5"
wallet_2 = "ST2CY5V39NHDPWSXMW9MDT5W3Rrk82T08U3U84X8"
wallet_3 = "ST2F4BK4GZ6C6A0MMDE1V9RE6DMP78A9CJC0Q65D"
wallet_4 = "ST2NHC0B3H68798XG8R3JRRX3P6PTEP9Q1GPD9V7"
wallet_5 = "ST2SB90M9K30S6XTHP50KDM13C0CP05S5C6NYVAV"
wallet_6 = "ST2X9L9V9J3U0V3Y6B9D0X6D6P7P8P8P8P8P8P8"
wallet_7 = "ST2Y9L9V9J3U0V3Y6B9D0X6D6P7P8P8P8P8P8P8"
wallet_8 = "ST2Z9L9V9J3U0V3Y6B9D0X6D6P7P8P8P8P8P8P8"
wallet_9 = "ST309L9V9J3U0V3Y6B9D0X6D6P7P8P8P8P8P8P8"
wallet_10 = "ST319L9V9J3U0V3Y6B9D0X6D6P7P8P8P8P8P8P8"

"""

for block in contract_blocks:
    new_content += block.strip() + "\n\n"

with open('Clarinet.toml', 'w') as f:
    f.write(new_content)
