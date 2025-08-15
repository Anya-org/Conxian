#!/usr/bin/env python3
"""Economic simulation for AutoVault autonomic fee behavior.

Simulates utilization and reserve ratio changes over discrete steps and calls the
same logic as on-chain (approximated) to observe fee evolution.
"""
from dataclasses import dataclass
import random, math, json

BPS_DENOM = 10_000

@dataclass
class VaultState:
    total_balance: int
    global_cap: int
    protocol_reserve: int
    fee_deposit_bps: int = 30
    fee_withdraw_bps: int = 10
    min_withdraw_fee: int = 5
    max_withdraw_fee: int = 100
    util_high: int = 8000
    util_low: int = 2000
    reserve_low: int = 500   # 5%
    reserve_high: int = 1500 # 15%
    deposit_step: int = 5
    withdraw_step: int = 5

    def utilization(self) -> int:
        if self.global_cap == 0:
            return 0
        return self.total_balance * BPS_DENOM // self.global_cap

    def reserve_ratio(self) -> int:
        if self.total_balance == 0:
            return 0
        return self.protocol_reserve * BPS_DENOM // self.total_balance

    def update_withdraw_fee(self):
        util = self.utilization()
        if util > self.util_high:
            self.fee_withdraw_bps = min(self.max_withdraw_fee, self.fee_withdraw_bps + self.withdraw_step)
        elif util < self.util_low:
            self.fee_withdraw_bps = max(self.min_withdraw_fee, self.fee_withdraw_bps - self.withdraw_step)

    def update_deposit_fee(self):
        ratio = self.reserve_ratio()
        if ratio < self.reserve_low:
            self.fee_deposit_bps = min(BPS_DENOM, self.fee_deposit_bps + self.deposit_step)
        elif ratio > self.reserve_high:
            self.fee_deposit_bps = max(0, self.fee_deposit_bps - self.deposit_step)

    def step(self, deposit: int, withdraw: int, yield_gain: int = 0):
        # Apply deposits (minus deposit fee to reserve)
        if deposit:
            fee = deposit * self.fee_deposit_bps // BPS_DENOM
            credited = deposit - fee
            self.protocol_reserve += fee // 2  # approximate split
            self.total_balance += credited
        # Apply withdrawals (withdraw fee captured)
        if withdraw:
            withdraw = min(withdraw, self.total_balance)
            fee = withdraw * self.fee_withdraw_bps // BPS_DENOM
            payout = withdraw - fee
            self.protocol_reserve += fee // 2
            self.total_balance -= withdraw
        # Apply yield
        if yield_gain:
            self.total_balance += yield_gain
            self.protocol_reserve += yield_gain // 10  # 10% performance share assumption
        # Update fees
        self.update_withdraw_fee()
        self.update_deposit_fee()


def simulate(steps=200, seed=0):
    random.seed(seed)
    state = VaultState(total_balance=0, global_cap=1_000_000, protocol_reserve=0)
    history = []
    for t in range(steps):
        deposit = max(0, int(random.gauss(20_000, 10_000))) if random.random() < 0.6 else 0
        withdraw = max(0, int(random.gauss(15_000, 8_000))) if random.random() < 0.4 else 0
        yield_gain = int(state.total_balance * random.uniform(0, 0.0005))  # up to 5 bps per step
        state.step(deposit, withdraw, yield_gain)
        history.append({
            't': t,
            'util': state.utilization(),
            'reserve_ratio': state.reserve_ratio(),
            'fee_deposit_bps': state.fee_deposit_bps,
            'fee_withdraw_bps': state.fee_withdraw_bps,
            'total_balance': state.total_balance,
            'protocol_reserve': state.protocol_reserve
        })
    return history

if __name__ == '__main__':
    h = simulate()
    print(json.dumps({'results': h[-10:], 'final': h[-1]}, indent=2))
