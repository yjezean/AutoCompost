#!/usr/bin/env python3
"""
Compost Calculations Module
Contains utility functions for C:N ratio calculations and control logic
"""
from typing import Dict, Optional


def calculate_cn_ratio(green_kg: float, brown_kg: float) -> Dict:
    """
    Calculate C:N ratio based on typical values:
    - Greens: ~20:1 C:N
    - Browns: ~60:1 C:N
    - Target mix: 25-30:1 C:N
    
    Args:
        green_kg: Weight of green waste in kilograms
        brown_kg: Weight of brown waste in kilograms
    
    Returns:
        Dictionary with current_ratio, optimal_ratio, status, and suggestions
    """
    if green_kg == 0 or brown_kg == 0:
        return {
            "current_ratio": 0.0,
            "optimal_ratio": 27.5,
            "green_waste_kg": green_kg,
            "brown_waste_kg": brown_kg,
            "suggested_brown_kg": None,
            "status": "insufficient_data"
        }
    
    # Simplified calculation (can be enhanced with material-specific ratios)
    green_cn = 20.0
    brown_cn = 60.0
    
    # Weighted average
    total_kg = green_kg + brown_kg
    green_weight = green_kg / total_kg
    brown_weight = brown_kg / total_kg
    
    current_ratio = (green_weight * green_cn) + (brown_weight * brown_cn)
    
    # Calculate suggested brown amount for optimal ratio (target: 27.5)
    target_ratio = 27.5
    if current_ratio < target_ratio:
        # Need more browns
        suggested_brown = green_kg * (green_cn / target_ratio - 1)
        status = "too_much_green"
    elif current_ratio > target_ratio * 1.2:
        # Too much browns
        suggested_brown = None
        status = "too_much_brown"
    else:
        suggested_brown = None
        status = "optimal"
    
    return {
        "current_ratio": round(current_ratio, 2),
        "optimal_ratio": target_ratio,
        "green_waste_kg": green_kg,
        "brown_waste_kg": brown_kg,
        "suggested_brown_kg": round(suggested_brown, 2) if suggested_brown else None,
        "status": status
    }


def check_temperature_control(temp: float, optimal_min: float = 55.0, optimal_max: float = 65.0) -> Dict[str, any]:
    """
    Determine temperature control actions for hot aerobic composting.
    
    Optimal range: 55-65°C (131-149°F) for hot aerobic composting
    
    Args:
        temp: Current temperature in Celsius
        optimal_min: Minimum optimal temperature (default: 55°C)
        optimal_max: Maximum optimal temperature (default: 65°C)
    
    Returns:
        Dictionary with control recommendations:
        - fan_action: "ON", "OFF", or None (no change needed)
        - lid_action: "OPEN", "CLOSED", or None
        - status: "optimal", "too_low", "too_high", "critical_high"
        - message: Human-readable status message
    """
    # Critical high temperature - emergency lid opening
    if temp > 70.0:
        return {
            "fan_action": "ON",
            "lid_action": "OPEN",
            "status": "critical_high",
            "message": f"Critical: Temperature {temp:.1f}°C exceeds 70°C - Emergency cooling required"
        }
    
    # Too high - need cooling
    if temp > optimal_max:
        return {
            "fan_action": "ON",
            "lid_action": "OPEN",
            "status": "too_high",
            "message": f"Temperature {temp:.1f}°C above optimal range (55-65°C) - Cooling needed"
        }
    
    # Too low - need heating (close lid, turn off fan)
    if temp < optimal_min:
        return {
            "fan_action": "OFF",
            "lid_action": "CLOSED",
            "status": "too_low",
            "message": f"Temperature {temp:.1f}°C below optimal range (55-65°C) - Heating needed"
        }
    
    # Optimal range
    return {
        "fan_action": None,  # Maintain current state
        "lid_action": None,   # Maintain current state
        "status": "optimal",
        "message": f"Temperature {temp:.1f}°C within optimal range (55-65°C)"
    }


def check_humidity_control(humidity: float, optimal_min: float = 50.0, optimal_max: float = 60.0) -> Dict[str, any]:
    """
    Determine humidity control actions.
    
    Optimal range: 50-60% water (by weight) for composting
    
    Args:
        humidity: Current humidity percentage
        optimal_min: Minimum optimal humidity (default: 50%)
        optimal_max: Maximum optimal humidity (default: 60%)
    
    Returns:
        Dictionary with control recommendations:
        - fan_action: "ON", "OFF", or None (no change needed)
        - status: "optimal", "too_low", "too_high"
        - message: Human-readable status message
    """
    # Too high - need dehumidification (fan on)
    if humidity > optimal_max:
        return {
            "fan_action": "ON",
            "status": "too_high",
            "message": f"Humidity {humidity:.1f}% above optimal range (50-60%) - Dehumidification needed"
        }
    
    # Too low - need moisture (fan off to retain moisture)
    if humidity < optimal_min:
        return {
            "fan_action": "OFF",
            "status": "too_low",
            "message": f"Humidity {humidity:.1f}% below optimal range (50-60%) - Moisture retention needed"
        }
    
    # Optimal range
    return {
        "fan_action": None,  # Maintain current state
        "status": "optimal",
        "message": f"Humidity {humidity:.1f}% within optimal range (50-60%)"
    }


def get_combined_control_recommendation(temp: float, humidity: float) -> Dict[str, any]:
    """
    Get combined control recommendations based on both temperature and humidity.
    
    Priority:
    1. Temperature control (critical for composting process)
    2. Humidity control (secondary)
    
    Args:
        temp: Current temperature in Celsius
        humidity: Current humidity percentage
    
    Returns:
        Dictionary with final control recommendations:
        - fan_action: "ON", "OFF", or None
        - lid_action: "OPEN", "CLOSED", or None
        - temp_status: Temperature status
        - humidity_status: Humidity status
        - message: Combined status message
    """
    temp_control = check_temperature_control(temp)
    humidity_control = check_humidity_control(humidity)
    
    # Priority: Temperature > Humidity
    # If temperature requires action, use that
    # Otherwise, use humidity control
    if temp_control["fan_action"] is not None:
        fan_action = temp_control["fan_action"]
    else:
        fan_action = humidity_control["fan_action"]
    
    # Lid is primarily for temperature control (emergency cooling)
    lid_action = temp_control["lid_action"]
    
    # Combine messages
    messages = [temp_control["message"], humidity_control["message"]]
    
    return {
        "fan_action": fan_action,
        "lid_action": lid_action,
        "temp_status": temp_control["status"],
        "humidity_status": humidity_control["status"],
        "temp_message": temp_control["message"],
        "humidity_message": humidity_control["message"],
        "message": " | ".join(messages)
    }

