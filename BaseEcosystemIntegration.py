#!/usr/bin/env python3
"""
Base Ecosystem Integration Utility
==================================

A comprehensive Python utility for integrating with Base blockchain ecosystem.
Provides tools for interacting with Base DEXs, bridges, and DeFi protocols.

Author: Crypto Challenge Repository
License: MIT
"""

import json
import time
import requests
from typing import Dict, List, Optional, Tuple
from decimal import Decimal
from dataclasses import dataclass
from enum import Enum

class BaseNetwork(Enum):
    """Base network configurations"""
    MAINNET = "base"
    TESTNET = "base-goerli"

@dataclass
class TokenInfo:
    """Token information structure"""
    address: str
    symbol: str
    decimals: int
    name: str
    is_native: bool = False

@dataclass
class PoolInfo:
    """Liquidity pool information"""
    address: str
    token0: TokenInfo
    token1: TokenInfo
    fee_tier: int
    tvl_usd: float
    volume_24h: float

class BaseEcosystemIntegration:
    """
    Main class for Base ecosystem integration
    Provides utilities for DeFi operations on Base blockchain
    """
    
    # Base network RPC endpoints
    RPC_ENDPOINTS = {
        BaseNetwork.MAINNET: "https://mainnet.base.org",
        BaseNetwork.TESTNET: "https://goerli.base.org"
    }
    
    # Common Base ecosystem token addresses
    BASE_TOKENS = {
        "ETH": TokenInfo("0x0000000000000000000000000000000000000000", "ETH", 18, "Ethereum", True),
        "USDC": TokenInfo("0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", "USDC", 6, "USD Coin"),
        "WETH": TokenInfo("0x4200000000000000000000000000000000000006", "WETH", 18, "Wrapped Ether"),
        "cbETH": TokenInfo("0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22", "cbETH", 18, "Coinbase Wrapped Staked ETH"),
    }
    
    def __init__(self, network: BaseNetwork = BaseNetwork.MAINNET):
        """Initialize Base ecosystem integration"""
        self.network = network
        self.rpc_url = self.RPC_ENDPOINTS[network]
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'User-Agent': 'BaseEcosystemIntegration/1.0'
        })
    
    def get_token_price(self, token_address: str) -> Optional[float]:
        """
        Get current token price in USD
        
        Args:
            token_address: Token contract address
            
        Returns:
            Token price in USD or None if not found
        """
        try:
            # Using a price API (placeholder - would use actual API)
            url = f"https://api.coingecko.com/api/v3/simple/token_price/base"
            params = {
                'contract_addresses': token_address,
                'vs_currencies': 'usd'
            }
            
            response = self.session.get(url, params=params, timeout=10)
            if response.status_code == 200:
                data = response.json()
                return data.get(token_address.lower(), {}).get('usd')
            
        except Exception as e:
            print(f"Error fetching token price: {e}")
        
        return None
    
    def calculate_swap_output(self, 
                            amount_in: float, 
                            reserve_in: float, 
                            reserve_out: float, 
                            fee_rate: float = 0.003) -> float:
        """
        Calculate swap output using constant product formula
        
        Args:
            amount_in: Input token amount
            reserve_in: Input token reserve
            reserve_out: Output token reserve  
            fee_rate: Swap fee rate (default 0.3%)
            
        Returns:
            Expected output amount
        """
        if reserve_in <= 0 or reserve_out <= 0:
            return 0
        
        # Apply fee
        amount_in_with_fee = amount_in * (1 - fee_rate)
        
        # Constant product formula: x * y = k
        numerator = amount_in_with_fee * reserve_out
        denominator = reserve_in + amount_in_with_fee
        
        return numerator / denominator
    
    def find_optimal_swap_route(self, 
                               token_in: str, 
                               token_out: str, 
                               amount_in: float) -> Dict:
        """
        Find optimal swap route between tokens
        
        Args:
            token_in: Input token symbol
            token_out: Output token symbol
            amount_in: Input amount
            
        Returns:
            Optimal route information
        """
        # Simplified routing logic
        direct_pools = self._get_direct_pools(token_in, token_out)
        multi_hop_routes = self._get_multi_hop_routes(token_in, token_out)
        
        best_route = {
            'route': [token_in, token_out],
            'expected_output': 0,
            'price_impact': 0,
            'gas_estimate': 150000
        }
        
        # Evaluate direct pools
        for pool in direct_pools:
            output = self.calculate_swap_output(
                amount_in, 
                pool['reserve_in'], 
                pool['reserve_out'],
                pool['fee_rate']
            )
            
            if output > best_route['expected_output']:
                best_route.update({
                    'expected_output': output,
                    'pool_address': pool['address'],
                    'price_impact': self._calculate_price_impact(amount_in, pool['reserve_in'])
                })
        
        return best_route
    
    def get_farming_opportunities(self) -> List[Dict]:
        """
        Get current yield farming opportunities on Base
        
        Returns:
            List of farming opportunities with APY and TVL
        """
        opportunities = [
            {
                'protocol': 'Uniswap V3',
                'pair': 'ETH/USDC',
                'apy': 12.5,
                'tvl': 50000000,
                'risk_level': 'Medium',
                'pool_address': '0x...',
                'fee_tier': 500
            },
            {
                'protocol': 'Aerodrome',
                'pair': 'WETH/cbETH',
                'apy': 8.3,
                'tvl': 25000000,
                'risk_level': 'Low',
                'pool_address': '0x...',
                'fee_tier': 100
            },
            {
                'protocol': 'BaseSwap',
                'pair': 'USDC/USDbC',
                'apy': 15.2,
                'tvl': 10000000,
                'risk_level': 'Low',
                'pool_address': '0x...',
                'fee_tier': 100
            }
        ]
        
        return sorted(opportunities, key=lambda x: x['apy'], reverse=True)
    
    def calculate_impermanent_loss(self, 
                                 initial_price_ratio: float, 
                                 current_price_ratio: float) -> float:
        """
        Calculate impermanent loss for LP positions
        
        Args:
            initial_price_ratio: Initial price ratio of token0/token1
            current_price_ratio: Current price ratio of token0/token1
            
        Returns:
            Impermanent loss as percentage
        """
        if initial_price_ratio <= 0 or current_price_ratio <= 0:
            return 0
        
        ratio_change = current_price_ratio / initial_price_ratio
        sqrt_ratio = ratio_change ** 0.5
        
        # IL formula: 2 * sqrt(ratio) / (1 + ratio) - 1
        il = 2 * sqrt_ratio / (1 + ratio_change) - 1
        
        return abs(il) * 100  # Return as percentage
    
    def get_bridge_quote(self, 
                        from_chain: str, 
                        to_chain: str, 
                        token: str, 
                        amount: float) -> Dict:
        """
        Get bridge quote for cross-chain transfers
        
        Args:
            from_chain: Source chain
            to_chain: Destination chain  
            token: Token to bridge
            amount: Amount to bridge
            
        Returns:
            Bridge quote with fees and time estimate
        """
        # Simplified bridge quote
        base_fee = 0.001  # ETH
        percentage_fee = 0.0005  # 0.05%
        
        total_fee = base_fee + (amount * percentage_fee)
        
        return {
            'from_chain': from_chain,
            'to_chain': to_chain,
            'token': token,
            'amount_in': amount,
            'amount_out': amount - total_fee,
            'fee': total_fee,
            'estimated_time': '2-5 minutes',
            'bridge_provider': 'Base Official Bridge'
        }
    
    def monitor_gas_prices(self) -> Dict:
        """
        Monitor current gas prices on Base
        
        Returns:
            Current gas price information
        """
        try:
            # Make RPC call to get gas price
            payload = {
                "jsonrpc": "2.0",
                "method": "eth_gasPrice",
                "params": [],
                "id": 1
            }
            
            response = self.session.post(self.rpc_url, json=payload, timeout=10)
            if response.status_code == 200:
                result = response.json()
                gas_price_wei = int(result['result'], 16)
                gas_price_gwei = gas_price_wei / 1e9
                
                return {
                    'gas_price_gwei': gas_price_gwei,
                    'fast': gas_price_gwei * 1.2,
                    'standard': gas_price_gwei,
                    'safe': gas_price_gwei * 0.8,
                    'timestamp': int(time.time())
                }
        
        except Exception as e:
            print(f"Error fetching gas prices: {e}")
        
        return {'error': 'Unable to fetch gas prices'}
    
    def _get_direct_pools(self, token_in: str, token_out: str) -> List[Dict]:
        """Get direct trading pools between two tokens"""
        # Placeholder implementation
        return [
            {
                'address': '0x...',
                'reserve_in': 1000000,
                'reserve_out': 2000000,
                'fee_rate': 0.003
            }
        ]
    
    def _get_multi_hop_routes(self, token_in: str, token_out: str) -> List[List[str]]:
        """Get multi-hop routes between tokens"""
        # Common routing through WETH or USDC
        if token_in != 'WETH' and token_out != 'WETH':
            return [[token_in, 'WETH', token_out]]
        if token_in != 'USDC' and token_out != 'USDC':
            return [[token_in, 'USDC', token_out]]
        return []
    
    def _calculate_price_impact(self, amount_in: float, reserve_in: float) -> float:
        """Calculate price impact of a swap"""
        if reserve_in <= 0:
            return 0
        return (amount_in / reserve_in) * 100

# Example usage and utility functions
def main():
    """Example usage of Base ecosystem integration"""
    base_integration = BaseEcosystemIntegration(BaseNetwork.MAINNET)
    
    print("=== Base Ecosystem Integration Demo ===")
    
    # Get farming opportunities
    print("\n1. Current Farming Opportunities:")
    opportunities = base_integration.get_farming_opportunities()
    for opp in opportunities[:3]:
        print(f"   {opp['protocol']} - {opp['pair']}: {opp['apy']:.1f}% APY")
    
    # Calculate swap output
    print("\n2. Swap Calculation:")
    output = base_integration.calculate_swap_output(1.0, 1000, 2000, 0.003)
    print(f"   Swapping 1 token: Expected output = {output:.4f}")
    
    # Calculate impermanent loss
    print("\n3. Impermanent Loss:")
    il = base_integration.calculate_impermanent_loss(1.0, 1.5)
    print(f"   50% price increase: IL = {il:.2f}%")
    
    # Monitor gas prices
    print("\n4. Current Gas Prices:")
    gas_info = base_integration.monitor_gas_prices()
    if 'gas_price_gwei' in gas_info:
        print(f"   Standard: {gas_info['standard']:.2f} gwei")
        print(f"   Fast: {gas_info['fast']:.2f} gwei")

if __name__ == "__main__":
    main()
