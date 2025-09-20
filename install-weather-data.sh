#!/bin/bash
# Exit on any error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31mPlease run as root\e[0m"
  exit 1
fi

# Colors and formatting
BLUE="\e[34m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BOLD="\e[1m"
UNDERLINE="\e[4m"
RESET="\e[0m"

# Sample airports from around the world
SAMPLE_AIRPORTS=(
  "KJFK:John F. Kennedy International Airport (New York, USA)"
  "EGLL:Heathrow Airport (London, UK)"
  "RJTT:Tokyo Haneda Airport (Tokyo, Japan)"
  "YSSY:Sydney Airport (Sydney, Australia)"
  "FACT:Cape Town International Airport (Cape Town, South Africa)"
  "SBGR:São Paulo–Guarulhos International Airport (São Paulo, Brazil)"
  "LTBA:Istanbul Atatürk Airport (Istanbul, Turkey)"
  "OMDB:Dubai International Airport (Dubai, UAE)"
  "VIDP:Indira Gandhi International Airport (Delhi, India)"
  "ZBAA:Beijing Capital International Airport (Beijing, China)"
)

# Introduction
display_intro() {
  clear
  echo -e "${BLUE}${BOLD}======================================================${RESET}"
  echo -e "${BLUE}${BOLD}    ENHANCED TELEMETRY HARBOR AIRPORT WEATHER        ${RESET}"
  echo -e "${BLUE}${BOLD}======================================================${RESET}"
  echo ""
  echo -e "This script will set up a comprehensive environmental monitoring service"
  echo -e "that collects extensive weather and air quality data from selected airports"
  echo -e "and sends it to your Telemetry Harbor endpoint."
  echo ""
  echo -e "${YELLOW}The Enhanced Airport Weather Collector will monitor:${RESET}"
  echo -e "  • ${BOLD}Weather Metrics:${RESET} Temperature, Pressure, Humidity, Dew Point"
  echo -e "  • ${BOLD}Wind Data:${RESET} Speed, Gusts, Direction, Variability"
  echo -e "  • ${BOLD}Precipitation:${RESET} Rain Rate, Snow Depth, Precipitation Type"
  echo -e "  • ${BOLD}Visibility:${RESET} Current Visibility, Fog Conditions"
  echo -e "  • ${BOLD}Air Quality:${RESET} PM2.5, PM10, Ozone, NO2, SO2, CO"
  echo -e "  • ${BOLD}Solar/UV:${RESET} UV Index, Solar Radiation, Cloud Cover"
  echo -e "  • ${BOLD}Atmospheric:${RESET} Sea Level Pressure, Altimeter Setting"
  echo -e "  • ${BOLD}Comfort Indices:${RESET} Heat Index, Wind Chill, Feels Like Temperature"
  echo ""
}

# Check if service is already installed
check_installation() {
  if [ -f "/etc/systemd/system/harbor-airport.service" ] || [ -f "/usr/local/bin/harbor-airport.sh" ]; then
    echo -e "${YELLOW}Enhanced Airport Weather Collector is already installed on this system.${RESET}"
    echo ""
    echo -e "What would you like to do?"
    echo -e "  ${BOLD}1.${RESET} Reinstall Enhanced Airport Weather Collector"
    echo -e "  ${BOLD}2.${RESET} Exit"
    
    read -p "Enter your choice (1-2): " REINSTALL_CHOICE
    
    if [ "$REINSTALL_CHOICE" = "1" ]; then
      uninstall "quiet"
      echo -e "${GREEN}Previous installation removed. Proceeding with new installation...${RESET}"
      echo ""
    else
      echo -e "${YELLOW}Installation cancelled.${RESET}"
      exit 0
    fi
  fi
}

# Uninstall function
uninstall() {
  if [ "$1" != "quiet" ]; then
    echo -e "${YELLOW}Uninstalling Enhanced Airport Weather Collector...${RESET}"
  fi
  
  # Stop and disable the service
  systemctl stop harbor-airport.service 2>/dev/null || true
  systemctl disable harbor-airport.service 2>/dev/null || true
  
  # Remove service file
  rm -f /etc/systemd/system/harbor-airport.service
  
  # Remove script
  rm -f /usr/local/bin/harbor-airport.sh
  
  # Reload systemd
  systemctl daemon-reload
  
  if [ "$1" != "quiet" ]; then
    echo -e "${GREEN}Enhanced Airport Weather Collector has been uninstalled.${RESET}"
    exit 0
  fi
}

# Check for uninstall argument
if [ "$1" = "--uninstall" ]; then
  uninstall
fi

# Main menu function
main_menu() {
  display_intro
  
  echo -e "${BLUE}${BOLD}What would you like to do?${RESET}"
  echo -e "  ${BOLD}1.${RESET} Install Enhanced Airport Weather Collector"
  echo -e "  ${BOLD}2.${RESET} Uninstall Enhanced Airport Weather Collector"
  echo -e "  ${BOLD}3.${RESET} Exit"
  echo ""
  
  read -p "Enter your choice (1-3): " MAIN_CHOICE
  
  case $MAIN_CHOICE in
    1)
      # Check if already installed
      check_installation
      install_collector
      ;;
    2)
      uninstall
      ;;
    3)
      echo -e "${YELLOW}Exiting...${RESET}"
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid choice. Exiting.${RESET}"
      exit 1
      ;;
  esac
}

# Install function
install_collector() {
  clear
  display_intro
  
  # API endpoint configuration
  echo -e "${BLUE}${BOLD}API Configuration:${RESET}"
  read -p "Enter telemetry batch API endpoint URL: " API_ENDPOINT
  read -p "Enter API key: " API_KEY
  
  # Weather API configuration
  echo ""
  echo -e "${BLUE}${BOLD}Weather API Configuration:${RESET}"
  echo -e "${YELLOW}For enhanced weather data, we'll use OpenWeatherMap API (free tier available)${RESET}"
  read -p "Enter OpenWeatherMap API key (optional, leave blank to use METAR only): " WEATHER_API_KEY
  
  # Airport configuration
  echo ""
  echo -e "${BLUE}${BOLD}Airport Configuration:${RESET}"
  echo -e "${YELLOW}Enter airport codes and names (ICAO code and full name).${RESET}"
  echo -e "Example: KJFK:John F. Kennedy International Airport"
  echo -e ""
  echo -e "${BLUE}${BOLD}Sample airports from around the world:${RESET}"
  for i in "${!SAMPLE_AIRPORTS[@]}"; do
    echo -e "  ${BOLD}$((i+1)).${RESET} ${SAMPLE_AIRPORTS[$i]}"
  done
  echo -e ""
  echo -e "Enter 'done' when finished adding airports."
  
  declare -a AIRPORT_CODES=()
  declare -a AIRPORT_NAMES=()
  
  while true; do
    read -p "Airport (or 'done'): " AIRPORT_INPUT
    
    if [ "$AIRPORT_INPUT" = "done" ]; then
      # If no airports added, ask again
      if [ ${#AIRPORT_CODES[@]} -eq 0 ]; then
        echo -e "${YELLOW}No airports added. Please add at least one airport.${RESET}"
        continue
      else
        break
      fi
    fi
    
    # Check if input is a number referring to a sample airport
    if [[ "$AIRPORT_INPUT" =~ ^[0-9]+$ ]] && [ "$AIRPORT_INPUT" -ge 1 ] && [ "$AIRPORT_INPUT" -le "${#SAMPLE_AIRPORTS[@]}" ]; then
      # Get the sample airport
      AIRPORT_INPUT="${SAMPLE_AIRPORTS[$((AIRPORT_INPUT-1))]}"
    fi
    
    # Split input by colon
    IFS=':' read -r CODE NAME <<< "$AIRPORT_INPUT"
    
    # Validate input
    if [ -z "$CODE" ] || [ -z "$NAME" ]; then
      echo -e "${RED}Invalid format. Please use CODE:NAME format.${RESET}"
      continue
    fi
    
    # Add to arrays
    AIRPORT_CODES+=("$CODE")
    AIRPORT_NAMES+=("$NAME")
    
    echo -e "${GREEN}Added: $CODE - $NAME${RESET}"
  done
  
  # Sampling rate configuration
  echo ""
  echo -e "${BLUE}${BOLD}Select sampling rate:${RESET}"
  echo -e "  ${BOLD}1.${RESET} Every 1 minute"
  echo -e "  ${BOLD}2.${RESET} Every 5 minutes"
  echo -e "  ${BOLD}3.${RESET} Every 15 minutes"
  echo -e "  ${BOLD}4.${RESET} Every 30 minutes"
  echo -e "  ${BOLD}5.${RESET} Every 1 hour"
  read -p "Enter your choice (1-5): " RATE_CHOICE
  
  case $RATE_CHOICE in
    1) SAMPLING_RATE=60 ;;
    2) SAMPLING_RATE=300 ;;
    3) SAMPLING_RATE=900 ;;
    4) SAMPLING_RATE=1800 ;;
    5) SAMPLING_RATE=3600 ;;
    *) 
      echo -e "${YELLOW}Invalid choice. Defaulting to 5 minutes.${RESET}"
      SAMPLING_RATE=300
      ;;
  esac
  
  echo -e "${YELLOW}Creating enhanced weather collection script...${RESET}"
  
  # Create the enhanced weather collection script
cat > /usr/local/bin/harbor-airport.sh << 'EOF'
#!/bin/bash

# Configuration will be injected here
API_ENDPOINT="__API_ENDPOINT__"
API_KEY="__API_KEY__"
WEATHER_API_KEY="__WEATHER_API_KEY__"
SAMPLING_RATE=__SAMPLING_RATE__

# Define airport codes with their official names
declare -A AIRPORT_NAMES
__AIRPORT_MAPPINGS__

# Array of airport codes
AIRPORT_CODES=(__AIRPORT_CODES__)

# Function to convert Celsius to Fahrenheit
celsius_to_fahrenheit() {
  local celsius=$1
  if [[ "$celsius" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
    echo "scale=2; ($celsius * 9/5) + 32" | bc -l 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

# Function to calculate heat index
calculate_heat_index() {
  local temp_f=$1
  local humidity=$2
  
  if [[ "$temp_f" =~ ^-?[0-9]+\.?[0-9]*$ ]] && [[ "$humidity" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    if (( $(echo "$temp_f >= 80" | bc -l) )); then
      local hi=$(echo "scale=2; -42.379 + 2.04901523*$temp_f + 10.14333127*$humidity - 0.22475541*$temp_f*$humidity - 0.00683783*$temp_f*$temp_f - 0.05481717*$humidity*$humidity + 0.00122874*$temp_f*$temp_f*$humidity + 0.00085282*$temp_f*$humidity*$humidity - 0.00000199*$temp_f*$temp_f*$humidity*$humidity" | bc -l 2>/dev/null)
      echo "$hi"
    else
      echo "$temp_f"
    fi
  else
    echo "0"
  fi
}

# Function to calculate wind chill
calculate_wind_chill() {
  local temp_f=$1
  local wind_mph=$2
  
  if [[ "$temp_f" =~ ^-?[0-9]+\.?[0-9]*$ ]] && [[ "$wind_mph" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    if (( $(echo "$temp_f <= 50 && $wind_mph >= 3" | bc -l) )); then
      local wc=$(echo "scale=2; 35.74 + 0.6215*$temp_f - 35.75*($wind_mph^0.16) + 0.4275*$temp_f*($wind_mph^0.16)" | bc -l 2>/dev/null)
      echo "$wc"
    else
      echo "$temp_f"
    fi
  else
    echo "0"
  fi
}

# Function to get coordinates for airport (simplified mapping)
get_airport_coordinates() {
  local code=$1
  case $code in
    KJFK) echo "40.6413,-73.7781" ;;    # John F. Kennedy International Airport (New York, USA)
    EGLL) echo "51.4700,-0.4543" ;;     # Heathrow Airport (London, UK)
    RJTT) echo "35.5494,139.7798" ;;    # Tokyo Haneda Airport (Tokyo, Japan)
    YSSY) echo "-33.9399,151.1753" ;;   # Sydney Airport (Sydney, Australia)
    FACT) echo "-33.9648,18.6017" ;;    # Cape Town International Airport (Cape Town, South Africa)
    SBGR) echo "-23.4356,-46.4731" ;;   # São Paulo–Guarulhos International Airport (São Paulo, Brazil)
    LTBA) echo "40.9769,28.8146" ;;     # Istanbul Atatürk Airport (Istanbul, Turkey)
    LTFM) echo "41.2753,28.7519" ;;     # Istanbul Airport (Istanbul, Turkey)
    LTAC) echo "40.1281,32.9951" ;;     # Esenboğa Airport (Ankara, Turkey)
    LTBJ) echo "38.2924,27.1564" ;;     # Adnan Menderes Airport (Izmir, Turkey)
    LTAI) echo "36.8987,30.8005" ;;     # Antalya Airport (Antalya, Turkey)
    OEJN) echo "21.6702,39.1565" ;;     # King Abdulaziz International Airport (Jeddah, Saudi Arabia)
    OERK) echo "24.9576,46.6988" ;;     # King Khalid International Airport (Riyadh, Saudi Arabia)
    OMRK) echo "25.6135,55.9388" ;;     # Ras Al Khaimah International Airport (Ras Al Khaimah, UAE)
    OMDB) echo "25.2532,55.3657" ;;     # Dubai International Airport (Dubai, UAE)
    VIDP) echo "28.5562,77.1000" ;;     # Indira Gandhi International Airport (Delhi, India)
    ZBAA) echo "40.0799,116.6031" ;;    # Beijing Capital International Airport (Beijing, China)
    EDDF) echo "50.0379,8.5622" ;;      # Frankfurt Airport (Frankfurt, Germany)
    *) echo "0,0" ;;                    # Default / Unknown
  esac
}

# Function to fetch enhanced weather data from OpenWeatherMap
fetch_enhanced_weather() {
  local code=$1
  local coords=$(get_airport_coordinates "$code")
  local lat=$(echo "$coords" | cut -d',' -f1)
  local lon=$(echo "$coords" | cut -d',' -f2)
  
  if [ "$WEATHER_API_KEY" != "" ] && [ "$lat" != "0" ] && [ "$lon" != "0" ]; then
    # Current weather
    local current_weather=$(curl -s "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$WEATHER_API_KEY&units=metric")
    
    # Air pollution
    local air_pollution=$(curl -s "https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$WEATHER_API_KEY")
    
    # UV Index
    local uv_data=$(curl -s "https://api.openweathermap.org/data/2.5/uvi?lat=$lat&lon=$lon&appid=$WEATHER_API_KEY")
    
    echo "$current_weather|$air_pollution|$uv_data"
  else
    echo "||"
  fi
}

# Function to extract weather data and push to Telemetry Harbor
push_weather_data() {
  local api_url="$API_ENDPOINT"
  local api_key="$API_KEY"
  
  for code in "${AIRPORT_CODES[@]}"; do
    local name="${AIRPORT_NAMES[$code]}"
    
    echo "[$(date)] Fetching comprehensive data for $name ($code)..."
    
    # Fetch METAR data
    local raw=$(curl -s "https://aviationweather.gov/api/data/metar?ids=$code&format=raw")
    
    # Fetch enhanced weather data if API key is available
    local enhanced_data=$(fetch_enhanced_weather "$code")
    local current_weather=$(echo "$enhanced_data" | cut -d'|' -f1)
    local air_pollution=$(echo "$enhanced_data" | cut -d'|' -f2)
    local uv_data=$(echo "$enhanced_data" | cut -d'|' -f3)
    
    # Parse METAR data with improved patterns
    local datetime_utc=$(echo "$raw" | grep -oP '\d{6}Z' | head -1)
    local temp_c=$(echo "$raw" | grep -oP '\s\d{2}/\d{2}\s' | head -1 | tr -d ' ' | cut -d'/' -f1)
    local dewpoint_c=$(echo "$raw" | grep -oP '\s\d{2}/\d{2}\s' | head -1 | tr -d ' ' | cut -d'/' -f2)
    local pressure_hpa=$(echo "$raw" | grep -oP 'Q\d{4}' | head -1 | cut -d'Q' -f2)
    local altimeter=$(echo "$raw" | grep -oP 'A\d{4}' | head -1 | cut -d'A' -f2)
    local wind_dir=$(echo "$raw" | grep -oP '\d{3}\d{2}KT' | head -1 | cut -c1-3)
    local wind_speed_kt=$(echo "$raw" | grep -oP '\d{3}(\d{2})KT' | head -1 | grep -oP '\d{2}KT' | cut -d'K' -f1)
    local wind_gust=$(echo "$raw" | grep -oP 'G\d{2}KT' | head -1 | cut -d'G' -f2 | cut -d'K' -f1)
    local visibility=$(echo "$raw" | grep -oP '\s\d{4}\s' | head -1 | tr -d ' ')
    
    # Set defaults if values are missing
    [ -z "$temp_c" ] && temp_c="15"
    [ -z "$dewpoint_c" ] && dewpoint_c="10"
    [ -z "$pressure_hpa" ] && pressure_hpa="1013"
    [ -z "$altimeter" ] && altimeter="2992"
    [ -z "$wind_dir" ] && wind_dir="0"
    [ -z "$wind_speed_kt" ] && wind_speed_kt="0"
    [ -z "$wind_gust" ] && wind_gust="0"
    [ -z "$visibility" ] && visibility="9999"
    
    # Calculate derived values
    local temp_f=$(celsius_to_fahrenheit "$temp_c")
    local dewpoint_f=$(celsius_to_fahrenheit "$dewpoint_c")
    local wind_speed_mph=$(echo "scale=2; $wind_speed_kt * 1.15078" | bc -l 2>/dev/null || echo "0")
    local wind_gust_mph=$(echo "scale=2; $wind_gust * 1.15078" | bc -l 2>/dev/null || echo "0")
    
    # Calculate humidity
    local humidity=$(echo "scale=2; 100 * e(17.625 * $dewpoint_c / (243.04 + $dewpoint_c)) / e(17.625 * $temp_c / (243.04 + $temp_c))" | bc -l 2>/dev/null || echo "50")
    
    # Calculate comfort indices
    local heat_index=$(calculate_heat_index "$temp_f" "$humidity")
    local wind_chill=$(calculate_wind_chill "$temp_f" "$wind_speed_mph")
    local feels_like="$temp_f"
    if (( $(echo "$temp_f >= 80" | bc -l) )); then
      feels_like="$heat_index"
    elif (( $(echo "$temp_f <= 50" | bc -l) )); then
      feels_like="$wind_chill"
    fi
    
    # Extract enhanced weather data if available
    local cloud_cover="0"
    local uv_index="0"
    local pm25="0"
    local pm10="0"
    local ozone="0"
    local no2="0"
    local so2="0"
    local co="0"
    local solar_radiation="0"
    local rain_rate="0"
    local snow_depth="0"
    
    if [ "$current_weather" != "" ]; then
      cloud_cover=$(echo "$current_weather" | jq -r '.clouds.all // 0' 2>/dev/null || echo "0")
      rain_rate=$(echo "$current_weather" | jq -r '.rain."1h" // 0' 2>/dev/null || echo "0")
      snow_depth=$(echo "$current_weather" | jq -r '.snow."1h" // 0' 2>/dev/null || echo "0")
    fi
    
    if [ "$air_pollution" != "" ]; then
      pm25=$(echo "$air_pollution" | jq -r '.list[0].components.pm2_5 // 0' 2>/dev/null || echo "0")
      pm10=$(echo "$air_pollution" | jq -r '.list[0].components.pm10 // 0' 2>/dev/null || echo "0")
      ozone=$(echo "$air_pollution" | jq -r '.list[0].components.o3 // 0' 2>/dev/null || echo "0")
      no2=$(echo "$air_pollution" | jq -r '.list[0].components.no2 // 0' 2>/dev/null || echo "0")
      so2=$(echo "$air_pollution" | jq -r '.list[0].components.so2 // 0' 2>/dev/null || echo "0")
      co=$(echo "$air_pollution" | jq -r '.list[0].components.co // 0' 2>/dev/null || echo "0")
    fi
    
    if [ "$uv_data" != "" ]; then
      uv_index=$(echo "$uv_data" | jq -r '.value // 0' 2>/dev/null || echo "0")
    fi
    
    # Estimate solar radiation based on UV index and cloud cover
    local base_solar=$(echo "scale=2; $uv_index * 25" | bc -l 2>/dev/null || echo "0")
    solar_radiation=$(echo "scale=2; $base_solar * (1 - $cloud_cover/100)" | bc -l 2>/dev/null || echo "0")
    
    # Get current date in ISO format
    local now=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
    
    # Prepare comprehensive metrics array
    local data="[
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Temperature_Celsius\", \"value\": $(printf "%.2f" "$temp_c")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Temperature_Fahrenheit\", \"value\": $(printf "%.2f" "$temp_f")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Dewpoint_Celsius\", \"value\": $(printf "%.2f" "$dewpoint_c")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Dewpoint_Fahrenheit\", \"value\": $(printf "%.2f" "$dewpoint_f")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Humidity_Percent\", \"value\": $(printf "%.2f" "$humidity")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Pressure_hPa\", \"value\": $(printf "%.0f" "$pressure_hpa")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Altimeter_Setting\", \"value\": $(printf "%.0f" "$altimeter")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Wind_Direction_Degrees\", \"value\": $(printf "%.0f" "$wind_dir")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Wind_Speed_Knots\", \"value\": $(printf "%.2f" "$wind_speed_kt")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Wind_Speed_MPH\", \"value\": $(printf "%.2f" "$wind_speed_mph")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Wind_Gust_Knots\", \"value\": $(printf "%.2f" "$wind_gust")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Wind_Gust_MPH\", \"value\": $(printf "%.2f" "$wind_gust_mph")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Visibility_Meters\", \"value\": $(printf "%.0f" "$visibility")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Heat_Index_F\", \"value\": $(printf "%.2f" "$heat_index")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Wind_Chill_F\", \"value\": $(printf "%.2f" "$wind_chill")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Feels_Like_F\", \"value\": $(printf "%.2f" "$feels_like")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Cloud_Cover_Percent\", \"value\": $(printf "%.2f" "$cloud_cover")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"UV_Index\", \"value\": $(printf "%.2f" "$uv_index")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Solar_Radiation_Wm2\", \"value\": $(printf "%.2f" "$solar_radiation")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Rain_Rate_mmh\", \"value\": $(printf "%.2f" "$rain_rate")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Snow_Depth_mm\", \"value\": $(printf "%.2f" "$snow_depth")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"PM2_5_ugm3\", \"value\": $(printf "%.2f" "$pm25")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"PM10_ugm3\", \"value\": $(printf "%.2f" "$pm10")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Ozone_ugm3\", \"value\": $(printf "%.2f" "$ozone")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"NO2_ugm3\", \"value\": $(printf "%.2f" "$no2")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"SO2_ugm3\", \"value\": $(printf "%.2f" "$so2")},
      {\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"CO_ugm3\", \"value\": $(printf "%.2f" "$co")}
    ]"

    
    # Print the payload (for debugging purposes)
    echo "Comprehensive payload for $name:"
    echo "$data" | jq '.' 2>/dev/null || echo "$data"
    
    # Send batch request to Telemetry Harbor
    response=$(curl -s -X POST "$api_url" -H "X-API-Key: $api_key" -H "Content-Type: application/json" -d "$data")
    
    # Check response from Telemetry Harbor
    if [[ $response == *"status_code"* && $response == *"500"* ]]; then
      echo "[$(date)] ERROR: Failed to send data for $name. Response: $response"
    else
      echo "[$(date)] Successfully sent comprehensive data for $name"
    fi
  done
  
  # Sleep for the configured interval before sending the next batch
  echo "[$(date)] Done. Sleeping for $(($SAMPLING_RATE/60)) min..."
  sleep $SAMPLING_RATE
}

# Function to test API connectivity
test_api_connection() {
  echo "Testing API connectivity..."
  
  # Get first airport for test
  local code="${AIRPORT_CODES[0]}"
  local name="${AIRPORT_NAMES[$code]}"
  
  # Create test JSON payload
  local now=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
  local test_data="[{\"time\": \"$now\", \"ship_id\": \"$name\", \"cargo_id\": \"Test\", \"value\": 1}]"
  
  # Send test request
  local response=$(curl -s -w "\n%{http_code}" -X POST "$API_ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $API_KEY" \
    -d "$test_data")
  
  # Extract HTTP status code
  local status_code=$(echo "$response" | tail -n1)
  local response_body=$(echo "$response" | head -n -1)
  
  if [ "$status_code" = "200" ]; then
    echo "API connection successful!"
    return 0
  else
    echo "API connection failed with status code: $status_code"
    echo "Response: $response_body"
    return 1
  fi
}

# Check for command line arguments
if [ "$1" = "test" ]; then
  test_api_connection
  exit $?
fi

# Main loop to push weather data at the configured interval
while true; do
  push_weather_data
done
EOF

  # Replace placeholders with actual values
  sed -i "s|__API_ENDPOINT__|$API_ENDPOINT|g" /usr/local/bin/harbor-airport.sh
  sed -i "s|__API_KEY__|$API_KEY|g" /usr/local/bin/harbor-airport.sh
  sed -i "s|__WEATHER_API_KEY__|$WEATHER_API_KEY|g" /usr/local/bin/harbor-airport.sh
  sed -i "s|__SAMPLING_RATE__|$SAMPLING_RATE|g" /usr/local/bin/harbor-airport.sh
  
  # Create airport mappings
  AIRPORT_MAPPINGS=""
  for i in "${!AIRPORT_CODES[@]}"; do
    AIRPORT_MAPPINGS+="AIRPORT_NAMES[\"${AIRPORT_CODES[$i]}\"]=\"${AIRPORT_NAMES[$i]}\"\n"
  done
  
  # Replace airport mappings placeholder
  sed -i "s|__AIRPORT_MAPPINGS__|$AIRPORT_MAPPINGS|g" /usr/local/bin/harbor-airport.sh
  
  # Create airport codes array
  AIRPORT_CODES_STR=$(printf "\"%s\" " "${AIRPORT_CODES[@]}")
  sed -i "s|__AIRPORT_CODES__|$AIRPORT_CODES_STR|g" /usr/local/bin/harbor-airport.sh
  
  # Make the script executable
  chmod +x /usr/local/bin/harbor-airport.sh
  
  # Create systemd service file
  cat > /etc/systemd/system/harbor-airport.service << EOF
[Unit]
Description=Enhanced Telemetry Harbor Airport Weather Collector
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/harbor-airport.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  # Test API connectivity
  echo -e "${YELLOW}Testing API connectivity...${RESET}"
  /usr/local/bin/harbor-airport.sh test
  
  # Check the return code from the test function
  TEST_RESULT=$?
  if [ $TEST_RESULT -ne 0 ]; then
    echo -e "${RED}API connectivity test failed. Please check your API endpoint and key.${RESET}"
    echo -e "${YELLOW}The service will not be started.${RESET}"
    exit 1
  fi
  
  # Enable and start the service
  systemctl daemon-reload
  systemctl enable harbor-airport.service
  systemctl start harbor-airport.service
  
  echo ""
  echo -e "${GREEN}${BOLD}=== Enhanced Installation Complete ===${RESET}"
  echo -e "${GREEN}Enhanced Airport Weather Collector has been installed and started.${RESET}"
  echo -e "${YELLOW}Monitoring the following airports with comprehensive metrics:${RESET}"
  for i in "${!AIRPORT_CODES[@]}"; do
    echo -e "  - ${AIRPORT_CODES[$i]}: ${AIRPORT_NAMES[$i]}"
  done
  echo -e "${YELLOW}Sampling rate:${RESET} Every $(($SAMPLING_RATE/60)) minutes"
  echo ""
  echo -e "${BLUE}${BOLD}Comprehensive Metrics Collected:${RESET}"
  echo -e "  • Temperature (°C & °F), Dewpoint, Humidity"
  echo -e "  • Pressure, Altimeter Setting"
  echo -e "  • Wind Speed/Direction/Gusts (knots & mph)"
  echo -e "  • Visibility, Cloud Cover"
  echo -e "  • Heat Index, Wind Chill, Feels Like Temperature"
  echo -e "  • UV Index, Solar Radiation"
  echo -e "  • Rain Rate, Snow Depth"
  echo -e "  • Air Quality: PM2.5, PM10, Ozone, NO2, SO2, CO"
  echo ""
  echo -e "${BLUE}To check service status:${RESET} systemctl status harbor-airport"
  echo -e "${BLUE}To view logs:${RESET} journalctl -u harbor-airport -f"
  echo -e "${BLUE}To manage the service:${RESET} Run this script again and select from the menu"
}

# Run the main menu
main_menu