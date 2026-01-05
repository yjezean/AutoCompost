#!/usr/bin/env python3
"""
Test script to verify control logic
Run this to test if humidity > 70% triggers fan and lid
"""
from compost_calculations import get_combined_control_recommendation

def test_humidity_control():
    """Test humidity control logic"""
    print("=" * 60)
    print("Testing Control Logic")
    print("=" * 60)
    
    # Test case 1: High humidity (70%), optimal temperature
    print("\nTest 1: Humidity 70%, Temperature 60°C (optimal)")
    print("-" * 60)
    result = get_combined_control_recommendation(60.0, 70.0)
    print(f"Fan Action: {result['fan_action']}")
    print(f"Lid Action: {result['lid_action']}")
    print(f"Temp Status: {result['temp_status']}")
    print(f"Humidity Status: {result['humidity_status']}")
    print(f"Message: {result['message']}")
    
    # Test case 2: High humidity (70%), low temperature
    print("\nTest 2: Humidity 70%, Temperature 50°C (too low)")
    print("-" * 60)
    result = get_combined_control_recommendation(50.0, 70.0)
    print(f"Fan Action: {result['fan_action']}")
    print(f"Lid Action: {result['lid_action']}")
    print(f"Temp Status: {result['temp_status']}")
    print(f"Humidity Status: {result['humidity_status']}")
    print(f"Message: {result['message']}")
    
    # Test case 3: High humidity (70%), high temperature
    print("\nTest 3: Humidity 70%, Temperature 70°C (too high)")
    print("-" * 60)
    result = get_combined_control_recommendation(70.0, 70.0)
    print(f"Fan Action: {result['fan_action']}")
    print(f"Lid Action: {result['lid_action']}")
    print(f"Temp Status: {result['temp_status']}")
    print(f"Humidity Status: {result['humidity_status']}")
    print(f"Message: {result['message']}")
    
    # Test case 4: Optimal conditions
    print("\nTest 4: Humidity 55%, Temperature 60°C (both optimal)")
    print("-" * 60)
    result = get_combined_control_recommendation(60.0, 55.0)
    print(f"Fan Action: {result['fan_action']}")
    print(f"Lid Action: {result['lid_action']}")
    print(f"Temp Status: {result['temp_status']}")
    print(f"Humidity Status: {result['humidity_status']}")
    print(f"Message: {result['message']}")
    
    print("\n" + "=" * 60)
    print("Expected Results:")
    print("  Test 1: Fan=ON, Lid=OPEN (humidity control)")
    print("  Test 2: Fan=OFF, Lid=CLOSED (temp control overrides)")
    print("  Test 3: Fan=ON, Lid=OPEN (temp control)")
    print("  Test 4: Fan=None, Lid=None (both optimal)")
    print("=" * 60)

if __name__ == "__main__":
    test_humidity_control()

