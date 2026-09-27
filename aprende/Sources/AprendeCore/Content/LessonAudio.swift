import Foundation

public enum LessonAudio {
    /// MP3 generado para la lección, si ya está en el paquete. Si no hay archivo, la app usa la voz del dispositivo.
    public static func bundledURL(lessonID: String) -> URL? {
        if let nested = Bundle.module.url(forResource: lessonID, withExtension: "mp3", subdirectory: "Audio") {
            return nested
        }
        return Bundle.module.url(forResource: lessonID, withExtension: "mp3")
    }
}
