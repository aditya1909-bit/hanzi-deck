#if WINDOWS
using System.Runtime.InteropServices.WindowsRuntime;
#endif
#if ANDROID
using Android.Gms.Extensions;
#endif

namespace HanziDeck;

public sealed class OcrService
{
    public async Task<string> RecognizeAsync(FileResult file)
    {
#if ANDROID
        await using var stream = await file.OpenReadAsync();
        using var bitmap = await Android.Graphics.BitmapFactory.DecodeStreamAsync(stream);
        if (bitmap is null) throw new InvalidDataException("The selected image could not be read.");
        using var image = Xamarin.Google.MLKit.Vision.Common.InputImage.FromBitmap(bitmap, 0);
        using var options = new Xamarin.Google.MLKit.Vision.Text.Chinese.ChineseTextRecognizerOptions.Builder().Build();
        using var recognizer = Xamarin.Google.MLKit.Vision.Text.TextRecognition.GetClient(options);
        var result = (Xamarin.Google.MLKit.Vision.Text.Text)await recognizer.Process(image);
        return result.GetText() ?? "";
#elif WINDOWS
        await using var stream = await file.OpenReadAsync();
        using var randomAccess = stream.AsRandomAccessStream();
        var decoder = await Windows.Graphics.Imaging.BitmapDecoder.CreateAsync(randomAccess);
        using var bitmap = await decoder.GetSoftwareBitmapAsync(
            Windows.Graphics.Imaging.BitmapPixelFormat.Bgra8,
            Windows.Graphics.Imaging.BitmapAlphaMode.Premultiplied);
        var language = new Windows.Globalization.Language("zh-Hans");
        var engine = Windows.Media.Ocr.OcrEngine.TryCreateFromLanguage(language)
            ?? Windows.Media.Ocr.OcrEngine.TryCreateFromUserProfileLanguages();
        if (engine is null) throw new NotSupportedException("Install a Chinese language pack to use image import.");
        var result = await engine.RecognizeAsync(bitmap);
        return result.Text;
#else
        await Task.CompletedTask;
        return "";
#endif
    }
}
