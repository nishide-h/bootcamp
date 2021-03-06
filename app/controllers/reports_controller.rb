class ReportsController < ApplicationController
  include ReportsHelper
  include Rails.application.routes.url_helpers
  include Gravatarify::Helper
  before_action :require_login
  before_action :set_report, only: %w(show)
  before_action :set_my_report, only: %i(edit update destroy)
  before_action :set_comments, only: %w(show edit update destroy)
  before_action :set_comment, only: %w(show edit update destroy)
  before_action :set_checks, only: %w(show)
  before_action :set_check, only: %w(show)
  before_action :set_footprints, only: %w(show)
  before_action :set_footprint, only: %w(show)
  before_action :set_user, only: :show
  before_action :set_categories, only: %w(new create edit update)

  def index
    @search_words = params[:word]&.squish&.split(/[[:blank:]]/)&.uniq
    @reports = Report.eager_load(:user, :comments, checks: :user).order(updated_at: :desc, id: :desc).page(params[:page])

    if params[:practice_id].present?
      @reports = @reports.joins(:practices).where(practices: { id: params[:practice_id]})
    end

    if @search_words.present?
      @reports = @reports.ransack(title_or_description_cont_all: @search_words).result
    end
  end

  def show
    @footprint.user = current_user
    @footprint.report = @report
    footprint!
  end

  def new
    @report = Report.new(reported_at: Date.current)
		@report.learning_times.build()

    if params[:id]
      report = current_user.reports.find(params[:id])
      @report.title = report.title
      @report.reported_at = report.reported_at
      @report.description = report.description
      @report.practices = report.practices
    end
  end

  def edit
    @report.user = current_user
  end

  def create
    @report = Report.new(report_params)
    @report.user = current_user
    if @report.save
      notify_to_slack(@report)
      redirect_to @report, notice: t("report_was_successfully_created")
    else
      render :new
    end
  end

  def update
    if @report.update(report_params)
      redirect_to @report, notice: t("report_was_successfully_updated")
    else
      render :edit
    end
  end

  def destroy
    @report.destroy
    redirect_to reports_url, notice: t("report_was_successfully_deleted")
  end

  private
    def footprint!
      if @report.user != current_user
        @footprints.where(user: @footprint.user).first_or_create
      end
    end

    def report_params
      params.require(:report).permit(
        :title,
        :reported_at,
        :description,
        practice_ids: [],
        learning_times_attributes: [:id, :started_at, :finished_at, :_destroy]
      )
    end

    def set_report
      @report = Report.find(params[:id])
    end

    def set_my_report
      @report = current_user.reports.find(params[:id])
    end

    def set_user
      @user = User.find_by(id: params[:user_id])
    end

    def set_check
      @check = Check.new
    end

    def set_checks
      @checks = @report.checks.order(created_at: :desc)
    end

    def set_footprint
      @footprint = Footprint.new
    end

    def set_footprints
      @footprints = Footprint.where(report_id: @report.id).order(created_at: :desc)
    end

    def set_comment
      @comment = Comment.new
    end

    def set_comments
      @comments = Comment.where(report_id: @report.id).order(created_at: :asc)
    end

    def set_categories
      @categories = Category.eager_load(:practices).where.not(practices: { id: nil }).order('categories.position ASC, practices.position ASC')
    end

    def notify_to_slack(report)
      name = "#{report.user.login_name}"
      link = "<#{report_url(report)}|#{report.title}>"

      notify "#{name} created #{link}",
        username: "#{report.user.login_name} (#{report.user.full_name})",
        icon_url: gravatar_url(report.user, secure: true),
        attachments: [{
          fallback: "report body.",
          text: report.description
        }]
    end
end
