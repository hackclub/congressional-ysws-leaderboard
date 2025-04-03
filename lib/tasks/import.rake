namespace :import do
  desc 'Import congressional districts from shapefile'
  task congressional_districts: :environment do
    require 'rgeo'
    require 'rgeo/shapefile'
    require 'rgeo/geos'
    
    puts "Importing congressional districts..."
    
    # State FIPS to postal code mapping
    STATE_FIPS = {
      '01' => 'AL', '02' => 'AK', '04' => 'AZ', '05' => 'AR', '06' => 'CA',
      '08' => 'CO', '09' => 'CT', '10' => 'DE', '11' => 'DC', '12' => 'FL',
      '13' => 'GA', '15' => 'HI', '16' => 'ID', '17' => 'IL', '18' => 'IN',
      '19' => 'IA', '20' => 'KS', '21' => 'KY', '22' => 'LA', '23' => 'ME',
      '24' => 'MD', '25' => 'MA', '26' => 'MI', '27' => 'MN', '28' => 'MS',
      '29' => 'MO', '30' => 'MT', '31' => 'NE', '32' => 'NV', '33' => 'NH',
      '34' => 'NJ', '35' => 'NM', '36' => 'NY', '37' => 'NC', '38' => 'ND',
      '39' => 'OH', '40' => 'OK', '41' => 'OR', '42' => 'PA', '44' => 'RI',
      '45' => 'SC', '46' => 'SD', '47' => 'TN', '48' => 'TX', '49' => 'UT',
      '50' => 'VT', '51' => 'VA', '53' => 'WA', '54' => 'WV', '55' => 'WI',
      '56' => 'WY'
    }
    
    # Create a GEOS factory for reading the shapefile
    factory = RGeo::Geos.factory(srid: 4326)
    
    # Path to the shapefile
    shapefile_path = Rails.root.join('data', 'shapefiles', 'cb_2022_us_cd118_500k.shp')
    
    # Read the shapefile
    RGeo::Shapefile::Reader.open(shapefile_path.to_s, factory: factory) do |file|
      file.each do |record|
        # Get state postal code from FIPS code
        state_fips = record['STATEFP']
        state = STATE_FIPS[state_fips]
        
        # Skip territories and non-states
        next unless state
        
        district_number = record['CD118FP'].to_i
        
        puts "FIPS: #{state_fips}, State: #{state}, District: #{district_number}"
        
        # Skip if this district already exists
        next if CongressionalDistrict.exists?(state: state, district_number: district_number)
        
        # Create the district
        district = CongressionalDistrict.create!(
          state: state,
          district_number: district_number,
          boundary: record.geometry
        )
        
        print "."  # Progress indicator
      end
    end
    
    puts "\nDone! Imported #{CongressionalDistrict.count} districts."
  end
end 