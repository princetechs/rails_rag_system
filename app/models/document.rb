class Document < ApplicationRecord
  include Neighbor::Model

  belongs_to :user
  has_one_attached :file

  validates :title, presence: true
  validates :file, presence: true

  attr_accessor :file_content

  before_save :process_file_content
  after_create :generate_embeddings

  has_neighbors :embedding # Removed distance option to fix ArgumentError

  def generate_embeddings
    return unless content.present?

    client = OpenAI::Client.new
    response = client.embeddings(
      parameters: {
        model: "text-embedding-ada-002",
        input: content
      }
    )

    update_column(:embedding, response.dig("data", 0, "embedding"))
  rescue => e
    Rails.logger.error "Failed to generate embeddings: #{e.message}"
  end

  private

  def process_file_content
    return unless file.attached? && file_changed?

    self.content = case file.content_type
    when "application/pdf"
      extract_pdf_content
    when "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      extract_docx_content
    when "text/plain"
      extract_text_content
    else
      raise "Unsupported file type: #{file.content_type}"
    end
  end

  def extract_pdf_content
    raise ActiveStorage::FileNotFoundError, "File not attached" unless file.attached?

    downloaded_file = file.download
    tempfile = Tempfile.new([ "document", ".pdf" ])
    begin
      tempfile.binmode
      tempfile.write(downloaded_file)
      tempfile.rewind
      reader = PDF::Reader.new(tempfile.path)
      reader.pages.map(&:text).join("\n")
    ensure
      tempfile.close
      tempfile.unlink
    end
  rescue PDF::Reader::MalformedPDFError => e
    errors.add(:file, "appears to be an invalid or corrupted PDF")
    nil
  rescue ActiveStorage::FileNotFoundError => e
    errors.add(:file, "could not be found")
    nil
  end

  def extract_docx_content
    raise ActiveStorage::FileNotFoundError, "File not attached" unless file.attached?

    downloaded_file = file.download
    tempfile = Tempfile.new([ "document", ".docx" ])
    begin
      tempfile.binmode
      tempfile.write(downloaded_file)
      tempfile.rewind
      doc = Docx::Document.open(tempfile.path)
      doc.paragraphs.map(&:text).join("\n")
    ensure
      tempfile.close
      tempfile.unlink
    end
  rescue => e
    errors.add(:file, "appears to be an invalid or corrupted DOCX file")
    nil
  rescue ActiveStorage::FileNotFoundError => e
    errors.add(:file, "could not be found")
    nil
  end

  def extract_text_content
    raise ActiveStorage::FileNotFoundError, "File not attached" unless file.attached?

    file.download
  rescue => e
    errors.add(:file, "could not be read")
    nil
  rescue ActiveStorage::FileNotFoundError => e
    errors.add(:file, "could not be found")
    nil
  end

  def file_changed?
    file.attached? && file.blob.present?
  end
end
