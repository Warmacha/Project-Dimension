using UnityEngine;
using UnityEngine.Rendering.Universal;

public class PixelationFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public int targetWidth = 320;
        public int targetHeight = 240;
        public Material upsampleMaterial;
        public RenderPassEvent injectionPoint = RenderPassEvent.AfterRenderingPostProcessing;
    }

    public Settings settings = new Settings();
    private BlitterPass m_Pass;

    public override void Create()
    {
        m_Pass = new BlitterPass(settings.targetWidth, settings.targetHeight, settings.upsampleMaterial);
        m_Pass.renderPassEvent = settings.injectionPoint;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var cameraType = renderingData.cameraData.cameraType;
        if (cameraType == CameraType.Preview || cameraType == CameraType.Reflection)
            return;

        renderer.EnqueuePass(m_Pass);
    }
}
