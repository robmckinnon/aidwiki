require 'morph'
require 'yaml'

# WikiPage.destroy_all

module Morph
  class Item
    include Morph
    
    def title_or_organisation
      title.blank? ? (organisation.blank? ? contractor.strip : organisation.strip) : title.strip
    end

    def path
      unless @path
        title = title_or_organisation.gsub("\t",' ').gsub("\r",' ').gsub("\n",' ').squeeze(' ').strip
        slug = FriendlyId::SlugString.new(title)
        normalized = slug.normalize!
        normalized = slug.approximate_ascii! unless slug.approximate_ascii!.blank?
        path = normalized[0..60]
        @path = "#{contract_no}-#{path}"
      end
      @path
    end
    
    def country_or_region_path
      @country_or_region_path ||= create_path(country_or_region.blank? ? 'no country' : country_or_region)
    end

    def contractor_path
      @contractor_path ||= create_path(contractor)
    end

    def organisation_path
      @organisation_path ||= create_path(organisation)
    end
    
    private
    def create_path name
      path = name.gsub("\t",' ').gsub("\r",' ').gsub("\n",' ').squeeze(' ').strip
      slug = FriendlyId::SlugString.new(path)
      normalized = slug.normalize!
      normalized = slug.approximate_ascii! unless slug.approximate_ascii!.blank?
      normalized
    end
  end
end

def as_euro amount
  number_to_currency(amount, :unit => "€", :precision => 0)
end

def projects_list items, type
  items = items.sort_by(&:title_or_organisation)
  titles = items.collect {|i| "* [[#{i.title_or_organisation}]] #{as_euro(i.amount_in_euro)}"}
  projects = titles.compact.join("\n")
  projects_list = "\n\nh2. #{type}Projects\n\n#{projects}"
  if items.size > 1
    total_amount = items.collect {|i| i.amount_in_euro}.compact.map {|a| a.to_i}.sum
    projects_list += "\n\n*Total amount: #{as_euro(total_amount)}*"
  end
  projects_list
end

def projects_by_country all_items, type
  projects_list = "\n\nh2. #{type}Projects\n"
  by_country = all_items.group_by(&:country_or_region)
  by_country.each do |country, items|
    items = items.sort_by(&:title_or_organisation)
    titles = items.collect {|i| "* [[#{i.title_or_organisation}]] #{as_euro(i.amount_in_euro)}"}
    projects = titles.compact.join("\n")
    projects_list += "\n\nh3. #{country}\n\n#{projects}"
    if items.size > 1
      total_amount = items.collect {|i| i.amount_in_euro}.compact.map {|a| a.to_i}.sum
      projects_list += "\n* *Total amount: #{as_euro total_amount}*"
    end
  end
  if all_items.size > 1
    total_amount = all_items.collect {|i| i.amount_in_euro}.compact.map {|a| a.to_i}.sum
    projects_list += "\n\n*Total #{type.downcase}projects amount: #{as_euro total_amount}*"
  end
  projects_list
end

def projects_by_dac_code codes, all_items, type
  projects_list = "\n\nh2. #{type}Projects\n"
  by_code = all_items.group_by(&:dac_code)
  by_code.each do |dac_code, items|
    items = items.sort_by(&:title_or_organisation)
    titles = items.collect {|i| "* [[#{i.title_or_organisation}]] #{as_euro(i.amount_in_euro)}"}
    projects = titles.compact.join("\n")
    
    if codes.has_key?(dac_code)
      projects_list += "\n\nh3. #{dac_code} #{codes[dac_code].first.description}\n\n#{projects}"
    else
      projects_list += "\n\nh3. #{dac_code}\n\n#{projects}"
    end

    if items.size > 1
      total_amount = items.collect {|i| i.amount_in_euro}.compact.map {|a| a.to_i}.sum
      projects_list += "\n* *Total amount: #{as_euro total_amount}*"
    end
  end
  if all_items.size > 1
    total_amount = all_items.collect {|i| i.amount_in_euro}.compact.map {|a| a.to_i}.sum
    projects_list += "\n\n*Total #{type.downcase}projects amount: #{as_euro total_amount}*"
  end
  projects_list
end


def create_page path, title, items, type=nil, by_country=true
  puts path
  page = WikiPage.find_or_create_by_path(path)
  page.title = title
  content = by_country ? projects_by_country(items, type) : projects_list(items, type)
  if page.content
    unless page.content.include?(content)
      page.content += content
      page.save
    end
  else
    page.content = content
    page.save
  end
end

include ActionView::Helpers::NumberHelper

def load_item item, codes, type
  puts item.path
  page = WikiPage.find_or_create_by_path(item.path)
  page.title = item.title
  links = [:country_or_region, :organisation, :contractor, :organisation_nationality, :contractor_nationality]
  lines = ["h2. #{type}Project\n\n"]
  
  item.class.morph_attributes.each do |key|
    value = item.send(key)
    value = value.gsub("\t",' ').gsub("\r",' ').gsub("\n",' ').squeeze(' ').strip unless value.blank?
    label = key.to_s.gsub('_',' ').capitalize
    if links.include?(key)
      if value && value.include?('Target groups')
        parts = value.split('Target groups')
        lines << "*#{label}* [[#{parts[0]}]] Target groups#{parts[1]}"
      elsif !value.blank?
        lines << "*#{label}* [[#{value}]]"
      end
    elsif key == :duration_unit
      line = lines.pop
      line = line + value
      lines << line
    elsif key == :ec_financing
      lines << "*EC financing* #{number_to_percentage(value, :precision => 1)}" unless value.blank?
    elsif key == :title
      # ignore
    elsif key.to_s[/in_euro/]
      lines << "*#{label}* #{as_euro value}" unless value.blank?
    elsif key == :dac_code && codes.has_key?(value)
      lines << "*DAC code* [[#{value} #{codes[value].first.description}]]"
    else
      lines << "*#{label}* #{value}"
    end
  end
  content = lines.join("\n")
  page.content = content
  page.save
end

def add_index name, names, &block
  page = WikiPage.find_or_create_by_path(name.strip.gsub(' ','-').downcase)
  page.title = name
  content = names.compact.sort.map {|c| "* [[#{c.strip}]]"}.join("\n")
  content = yield content if block
  page.content = content
  page.save
end

def add_countries items, file
  country_or_regions = []
  items.group_by(&:country_or_region_path).each do |path, items|
    country_or_region = items.first.country_or_region
    create_page(path, country_or_region, items, "#{file[/procurement|grant/].capitalize} ", false)
    country_or_regions << country_or_region
  end
  add_index 'Countries and Regions', country_or_regions
end

def load_file file, codes, type, &block
  csv = IO.read("#{RAILS_ROOT}/data/#{file}")
  items = Morph.from_csv(csv, 'Item')
  # add_countries items, file
  yield items, codes, type
  items.each { |item| load_item(item, codes, type) }
end

def load_dac_codes
  csv = IO.read("#{RAILS_ROOT}/data/dac_codes.csv")
  codes = Morph.from_csv(csv, 'Code')
  codes.each do |code|
    path = code.code
    page = WikiPage.find_or_create_by_path(path)
    page.title = "#{code.code} #{code.description}"
    page.content = (code.notes || '')
    page.save
  end
  code_names = codes.collect{|c| "#{c.code.size < 5 ? "#{c.code}00" : c.code} #{c.description}"}
  add_index('DAC Codes', code_names) {|content| content.gsub("00 ",' ')}
  codes.group_by(&:code)
end

def add_to_dac_codes codes, items, type
  items.group_by(&:dac_code).each do |dac_code, items|
    puts dac_code
    if codes.has_key?(dac_code)
      code = codes[dac_code].first
      path = code.code
      puts "adding #{items.size} to #{code.code}"
      create_page(path, "#{code.code} #{code.description}", items, type)
    end
  end
end

codes = load_dac_codes

load_file('ec_beneficiaries_grants.csv', codes, 'Grant ') do |items, codes, type|
  add_to_dac_codes codes, items, type
end
load_file('ec_beneficiaries_procurement.csv', codes, 'Procurement ') do |items, codes, type|
  add_to_dac_codes codes, items, type
end

load_file('ec_beneficiaries_grants.csv', codes) do |items, codes|
  type = 'Grant '
  add_to_dac_codes codes, items, type
  organisations = []
  items.group_by(&:organisation_path).each do |path, items|
    organisation = items.first.organisation
    create_page(path, organisation, items, type)
    organisations << organisation
  end
  add_index 'Organisations', organisations
end

load_file('ec_beneficiaries_procurement.csv', codes) do |items, codes|
  type = 'Procurement '
  add_to_dac_codes codes, items, type
  contractors = []
  items.group_by(&:contractor_path).each do |path, items|
    contractor = items.first.contractor
    create_page(path, contractor, items, type)
    contractors << contractor
  end
  add_index 'Contractors', contractors
end

