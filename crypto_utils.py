#!/usr/bin/env python3
"""
Cryptocurrency Utilities Module
A comprehensive toolkit for cryptocurrency operations and blockchain interactions.
"""

import hashlib
import hmac
import time
import json
from typing import Dict, List, Optional, Tuple
from decimal import Decimal


class CryptoUtils:
    """Utility class for cryptocurrency operations."""
    
    def __init__(self):
        self.supported_currencies = ['BTC', 'ETH', 'ADA', 'DOT', 'LINK', 'UNI']
    
    def calculate_hash(self, data: str, algorithm: str = 'sha256') -> str:
        """Calculate hash of given data using specified algorithm."""
        if algorithm == 'sha256':
            return hashlib.sha256(data.encode()).hexdigest()
        elif algorithm == 'sha1':
            return hashlib.sha1(data.encode()).hexdigest()
        elif algorithm == 'md5':
            return hashlib.md5(data.encode()).hexdigest()
        else:
            raise ValueError(f"Unsupported algorithm: {algorithm}")
    
    def generate_merkle_root(self, transactions: List[str]) -> str:
        """Generate Merkle root from list of transaction hashes."""
        if not transactions:
            return ""
        
        # Create a copy to avoid modifying original list
        hashes = [self.calculate_hash(tx) for tx in transactions]
        
        while len(hashes) > 1:
            next_level = []
            for i in range(0, len(hashes), 2):
                if i + 1 < len(hashes):
                    combined = hashes[i] + hashes[i + 1]
                else:
                    combined = hashes[i] + hashes[i]  # Duplicate if odd number
                next_level.append(self.calculate_hash(combined))
            hashes = next_level
        
        return hashes[0]
    
    def validate_bitcoin_address(self, address: str) -> bool:
        """Validate Bitcoin address format."""
        if not address:
            return False
        
        # Basic validation for different Bitcoin address formats
        if address.startswith('1') and len(address) >= 26 and len(address) <= 35:
            return True  # Legacy P2PKH
        elif address.startswith('3') and len(address) >= 26 and len(address) <= 35:
            return True  # P2SH
        elif address.startswith('bc1') and len(address) >= 42:
            return True  # Bech32
        
        return False
    
    def calculate_transaction_fee(self, input_count: int, output_count: int, 
                                fee_per_byte: float = 10.0) -> float:
        """Calculate estimated Bitcoin transaction fee."""
        # Rough estimation: 148 bytes per input + 34 bytes per output + 10 bytes overhead
        estimated_size = (input_count * 148) + (output_count * 34) + 10
        return estimated_size * fee_per_byte / 100000000  # Convert to BTC
    
    def generate_wallet_seed(self, entropy_bits: int = 128) -> str:
        """Generate a random seed for wallet creation."""
        import secrets
        entropy = secrets.randbits(entropy_bits)
        return hex(entropy)[2:].zfill(entropy_bits // 4)


class DeFiCalculator:
    """Calculator for DeFi operations and yield farming."""
    
    def calculate_apy(self, principal: float, final_amount: float, 
                     time_period_days: int) -> float:
        """Calculate Annual Percentage Yield (APY)."""
        if principal <= 0 or time_period_days <= 0:
            return 0.0
        
        daily_rate = (final_amount / principal) ** (1 / time_period_days) - 1
        apy = ((1 + daily_rate) ** 365 - 1) * 100
        return round(apy, 2)
    
    def calculate_impermanent_loss(self, price_ratio: float) -> float:
        """Calculate impermanent loss for AMM liquidity provision."""
        if price_ratio <= 0:
            return 0.0
        
        # Formula: 2 * sqrt(price_ratio) / (1 + price_ratio) - 1
        import math
        loss = 2 * math.sqrt(price_ratio) / (1 + price_ratio) - 1
        return abs(loss) * 100  # Return as percentage
    
    def calculate_compound_interest(self, principal: float, rate: float, 
                                  compounds_per_year: int, years: float) -> float:
        """Calculate compound interest for staking rewards."""
        if principal <= 0 or rate <= 0:
            return principal
        
        amount = principal * (1 + rate / compounds_per_year) ** (compounds_per_year * years)
        return round(amount, 8)


class TechnicalAnalysis:
    """Technical analysis indicators for cryptocurrency trading."""
    
    def calculate_sma(self, prices: List[float], period: int) -> List[float]:
        """Calculate Simple Moving Average."""
        if len(prices) < period:
            return []
        
        sma_values = []
        for i in range(period - 1, len(prices)):
            avg = sum(prices[i - period + 1:i + 1]) / period
            sma_values.append(round(avg, 8))
        
        return sma_values
    
    def calculate_rsi(self, prices: List[float], period: int = 14) -> List[float]:
        """Calculate Relative Strength Index."""
        if len(prices) < period + 1:
            return []
        
        gains = []
        losses = []
        
        for i in range(1, len(prices)):
            change = prices[i] - prices[i - 1]
            if change > 0:
                gains.append(change)
                losses.append(0)
            else:
                gains.append(0)
                losses.append(abs(change))
        
        rsi_values = []
        for i in range(period - 1, len(gains)):
            avg_gain = sum(gains[i - period + 1:i + 1]) / period
            avg_loss = sum(losses[i - period + 1:i + 1]) / period
            
            if avg_loss == 0:
                rsi = 100
            else:
                rs = avg_gain / avg_loss
                rsi = 100 - (100 / (1 + rs))
            
            rsi_values.append(round(rsi, 2))
        
        return rsi_values
    
    def detect_support_resistance(self, prices: List[float], 
                                window: int = 5) -> Dict[str, List[float]]:
        """Detect support and resistance levels."""
        if len(prices) < window * 2 + 1:
            return {'support': [], 'resistance': []}
        
        support_levels = []
        resistance_levels = []
        
        for i in range(window, len(prices) - window):
            # Check for local minimum (support)
            is_support = all(prices[i] <= prices[i + j] for j in range(-window, window + 1) if j != 0)
            if is_support:
                support_levels.append(prices[i])
            
            # Check for local maximum (resistance)
            is_resistance = all(prices[i] >= prices[i + j] for j in range(-window, window + 1) if j != 0)
            if is_resistance:
                resistance_levels.append(prices[i])
        
        return {
            'support': list(set(support_levels)),
            'resistance': list(set(resistance_levels))
        }


# Example usage and testing
if __name__ == "__main__":
    # Initialize utilities
    crypto = CryptoUtils()
    defi = DeFiCalculator()
    ta = TechnicalAnalysis()
    
    # Test cryptocurrency utilities
    print("=== Cryptocurrency Utilities Test ===")
    test_data = "Hello, Blockchain!"
    print(f"SHA256 Hash: {crypto.calculate_hash(test_data)}")
    
    transactions = ["tx1", "tx2", "tx3", "tx4"]
    merkle_root = crypto.generate_merkle_root(transactions)
    print(f"Merkle Root: {merkle_root}")
    
    # Test DeFi calculations
    print("\n=== DeFi Calculator Test ===")
    apy = defi.calculate_apy(1000, 1200, 365)
    print(f"APY: {apy}%")
    
    il = defi.calculate_impermanent_loss(2.0)
    print(f"Impermanent Loss: {il}%")
    
    # Test technical analysis
    print("\n=== Technical Analysis Test ===")
    sample_prices = [100, 102, 101, 103, 105, 104, 106, 108, 107, 109]
    sma = ta.calculate_sma(sample_prices, 5)
    print(f"SMA (5): {sma}")
    
    support_resistance = ta.detect_support_resistance(sample_prices)
    print(f"Support/Resistance: {support_resistance}")
    
    print("\n=== Crypto Utils Module Ready ===")
