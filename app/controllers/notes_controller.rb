class NotesController < ApplicationController
  before_action :set_client
  before_action :set_note, only: [ :show, :destroy ]

  def index
    @notes = @client.notes.recent.includes(:created_by)

    respond_to do |format|
      format.html # Para acceso directo
      format.turbo_stream # Para cargar en el frame
    end
  end

  def show
    # Para mostrar una nota específica si es necesario
  end

  def create
    @note = @client.notes.build(note_params)
    @note.created_by = Current.user # Usando la autenticación por defecto de Rails 8

    respond_to do |format|
      if @note.save
        format.turbo_stream { render :create }
        format.html { redirect_to @client, notice: "Nota creada exitosamente." }
        format.json { render :show, status: :created, location: [ @client, @note ] }
      else
        format.turbo_stream { render turbo_stream: turbo_stream.update("note-form", partial: "notes/form_with_errors", locals: { client: @client, note: @note }) }
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @note.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @note.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("note_#{@note.id}") }
      format.html { redirect_to @client, notice: "Nota eliminada exitosamente." }
      format.json { head :no_content }
    end
  end

  private

  def set_client
    @client = Client.find(params[:client_id])
  end

  def set_note
    @note = @client.notes.find(params[:id])
  end

  def note_params
    params.require(:note).permit(:text)
  end
end
