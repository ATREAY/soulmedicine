# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include ErrorHandlers

  before_action :set_locale

  protected

  def set_locale
    locale = params[:locale].to_s.strip.to_sym
    LocalesService.current = locale
  end

  def default_url_options
    { locale: LocalesService.current }
  end

  def courses_service
    @courses_service ||= CoursesService.new(STORYBLOK_CLIENT)
  end
end
