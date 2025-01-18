class DocumentsController < ApplicationController
  before_action :require_authentication
  before_action :set_document, only: [ :show, :destroy ]

  def index
    @documents = Current.user.documents.order(created_at: :desc)
  end

  def show
  end

  def new
    @document = Document.new
  end

  def create
    @document = Current.user.documents.build(document_params)

    if @document.save
      redirect_to @document, notice: "Document was successfully uploaded."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @document.destroy
    redirect_to documents_path, notice: "Document was successfully deleted."
  end

  def query
    return if params[:query].blank?

    client = OpenAI::Client.new
    query_embedding = client.embeddings(
      parameters: {
        model: "text-embedding-ada-002",
        input: params[:query]
      }
    ).dig("data", 0, "embedding")

    # Find relevant documents using vector similarity
    relevant_docs = Current.user.documents
      .order(Arel.sql("embedding <-> ARRAY[#{query_embedding.join(',')}]::vector"))
      .limit(3)

    # Generate response using ChatGPT
    context = relevant_docs.map { |doc| doc.content }.join("\n\n")

    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [
          { role: "system", content: "You are a helpful assistant. Use the provided context to answer the user's question. If you cannot find the answer in the context, say so." },
          { role: "user", content: "Context:\n#{context}\n\nQuestion: #{params[:query]}" }
        ]
      }
    )

    @answer = response.dig("choices", 0, "message", "content")
    @relevant_docs = relevant_docs
  end

  private

  def set_document
    @document = Current.user.documents.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :file)
  end
end
