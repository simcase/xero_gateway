# coding: utf-8
require File.join(File.dirname(__FILE__), 'account')
require 'bigdecimal'

module XeroGateway
  class LineItem
    include Money

    TAX_TYPE = Account::TAX_TYPE unless defined?(TAX_TYPE)

    # Any errors that occurred when the #valid? method called.
    attr_reader :errors

    # All accessible fields
    attr_accessor :line_item_id, :description, :quantity, :unit_amount, :item_code,
                  :tax_type, :tax_amount, :discount_rate, :account_code, :tracking,
                  :options

    def initialize(params = {}, options = {})
      @errors ||= []
      @tracking ||= []
      @quantity = 1
      @unit_amount = BigDecimal.new('0')
      @discount_rate = BigDecimal.new('0')
      @options = options

      params.each do |k,v|
        self.send("#{k}=", v)
      end
    end

    # Validate the LineItem record according to what will be valid by the gateway.
    #
    # Usage:
    #  line_item.valid?     # Returns true/false
    #
    #  Additionally sets line_item.errors array to an array of field/error.
    def valid?
      @errors = []

      if !line_item_id.nil? && line_item_id !~ GUID_REGEX
        @errors << ['line_item_id', 'must be blank or a valid Xero GUID']
      end

      unless description
        @errors << ['description', "can't be blank"]
      end

      if tax_type && !TAX_TYPE[tax_type]
        @errors << ['tax_type', "must be one of #{TAX_TYPE.keys.join('/')}"]
      end

      @errors.size == 0
    end

    def has_tracking?
      return false if tracking.nil?

      if tracking.is_a?(Array)
        return tracking.any?
      else
        return tracking.is_a?(TrackingCategory)
      end
    end

    # Deprecated (but API for setter remains).
    #
    # As line_amount must equal quantity * unit_amount for the API call to pass, this is now
    # automatically calculated in the line_amount method.
    def line_amount=(value)
    end

    # Calculate the line_amount as quantity * unit_amount as this value must be correct
    # for the API call to succeed.
    def line_amount
      # TODO LineAmount похоже вообще не обязательное поле в апи. Оно нам надо, его отправлять?
      # TODO По хорошему unit_amount надо при инициализации превращать в BigDecimal, а не тут
      unit_amount_big = BigDecimal.new(unit_amount.to_s)
      discount_rate_big = BigDecimal.new(discount_rate.round(2).to_s)
      quantity * unit_amount_big * ((100 - discount_rate_big) / 100)
    end

    def to_xml(b = Builder::XmlMarkup.new)
      b.LineItem {
        b.Description description
        b.Quantity quantity if quantity
        b.UnitAmount LineItem.format_money(unit_amount)
        b.ItemCode item_code if item_code
        b.TaxType tax_type if tax_type
        b.TaxAmount tax_amount if tax_amount
        b.DiscountRate discount_rate if discount_rate
        # NOTE option :dont_set_line_amount due to bug https://community.xero.com/developer/discussion/39048510
        if line_amount && !options[:dont_set_line_amount]
          b.LineAmount LineItem.format_money(line_amount)
        end
        b.AccountCode account_code if account_code
        if has_tracking?
          b.Tracking {
            # Due to strange retardness in the Xero API, the XML structure for a tracking category within
            # an invoice is different to a standalone tracking category.
            # This means rather than going category.to_xml we need to call the special category.to_xml_for_invoice_messages
            (tracking.is_a?(TrackingCategory) ? [tracking] : tracking).each do |category|
              category.to_xml_for_invoice_messages(b)
            end
          }
        end
      }
    end

    def self.from_xml(line_item_element)
      line_item = LineItem.new
      line_item_element.children.each do |element|
        case(element.name)
          when "LineItemID" then line_item.line_item_id = element.text
          when "Description" then line_item.description = element.text
          when "Quantity" then line_item.quantity = BigDecimal(element.text)
          when "UnitAmount" then line_item.unit_amount = BigDecimal.new(element.text)
          when "ItemCode" then line_item.item_code = element.text
          when "TaxType" then line_item.tax_type = element.text
          when "TaxAmount" then line_item.tax_amount = BigDecimal.new(element.text)
          when "DiscountRate" then line_item.discount_rate = BigDecimal.new(element.text)
          when "LineAmount" then line_item.line_amount = BigDecimal.new(element.text)
          when "AccountCode" then line_item.account_code = element.text
          when "Tracking" then
            element.children.each do | tracking_element |
              line_item.tracking << TrackingCategory.from_xml(tracking_element)
            end
        end
      end
      line_item
    end

    def ==(other)
      [:description, :quantity, :unit_amount, :tax_type, :tax_amount, :discount_rate, :line_amount, :account_code, :item_code].each do |field|
        return false if send(field) != other.send(field)
      end
      return true
    end
  end
end
