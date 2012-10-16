module PiggybakCoupons
  class Coupon < ActiveRecord::Base
    self.table_name = 'coupons'

    has_many :coupon_applications

    attr_accessor :coupon_type, :application_detail
    attr_accessible :code, :amount, :discount_type, :min_cart_total, :expiration_date, :allowed_applications

    validates_presence_of :code, :amount, :discount_type, :min_cart_total, :expiration_date, :allowed_applications
    validates_uniqueness_of :code
    validates_numericality_of :amount, :greater_than_or_equal_to => 0
    validates_numericality_of :min_cart_total, :greater_than_or_equal_to => 0
    validates_numericality_of :allowed_applications, :greater_than_or_equal_to => 0
    validate :validate_dollar_discount

    def validate_dollar_discount
      if self.discount_type == "$" && self.amount > self.min_cart_total
        self.errors.add(:min_cart_total, "Minimum cart total must be greater than amount for dollar discount.")
      end
    end

    def coupon_type
      if self.discount_type == "ship"
        return "free shipping"
      elsif self.discount_type == "%"
        return "#{self.amount}#{self.discount_type}"
      elsif self.discount_type == "$"
        return "#{self.discount_type}#{sprintf("%.2f", self.amount)}"
      end
    end

    def discount_type_enum 
      [['Percent', '%'], ['Dollar', '$'], ['Free Shipping', 'ship']]
    end

    def application_detail
      "#{self.coupon_applications.size} of #{self.allowed_applications} allowed uses applied"
    end

    def self.valid_coupon(code, object, already_applied)
      # First check
      coupon = Coupon.find_by_code(code)
      return "Invalid coupon code." if coupon.nil?

      # Expiration date check
      return "Expired coupon." if coupon.expiration_date < Date.today

      # Min cart total check
      return "Order does not meet minimum total for coupon." if object.subtotal < coupon.min_cart_total.to_f

      # Allowed applications check 
      return "Coupon has already been used #{coupon.allowed_applications} times." if !already_applied && (coupon.coupon_applications.size >= coupon.allowed_applications)

      if object.is_a?(Piggybak::Order) && coupon.discount_type == "ship"
        ship_line_item = object.line_items.detect { |li| li.line_item_type == "shipment" }
        return "No shipping on this order." if !ship_line_item
      end 
      coupon
    end
     
    def self.apply_discount(code, object, shipcost = 0.0)
      coupon = Coupon.find_by_code(code)
      return 0 if coupon.nil?
 
      # $ or % discount_type discount   
      if coupon.discount_type == "$"
        return -1*coupon.amount
      elsif coupon.discount_type == "%"
        return (-1.to_f*(coupon.amount/100)*object.subtotal).to_c
      elsif coupon.discount_type == "ship"
        if object.is_a?(Piggybak::Order)
          ship_line_item = object.line_items.detect { |li| li.line_item_type == "shipment" }
          if ship_line_item
            return -1*ship_line_item.price
          else
            return 0.00
          end
        elsif object.is_a?(Piggybak::Cart)
          return -1*shipcost.to_f
        end
      end
    end   
  end
end
