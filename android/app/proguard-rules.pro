# Mantém classes e métodos usados pelo Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Mantém classes de serialização de dados (se você usar pacotes como json_serializable)
-keep class com.example.entradas_pev_app.** { *; }

# Mantém anotações e classes relacionadas
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

# Evita problemas com bibliotecas comuns
-dontwarn com.google.**
-dontwarn okio.**
-dontwarn okhttp3.**