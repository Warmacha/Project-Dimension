using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;

public class BlitterPass : ScriptableRenderPass
{
    private int m_Width;
    private int m_Height;

    private Material m_UpsampleMaterial;

    class PassData
    {
        public TextureHandle source;
        public Material material;
    }

    public BlitterPass(int width, int height, Material upsampleMaterial)
    {
        m_Width = width;
        m_Height = height;
        m_UpsampleMaterial = upsampleMaterial;
        requiresIntermediateTexture = true;
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        var resourceData = frameData.Get<UniversalResourceData>();
        var cameraData = frameData.Get<UniversalCameraData>();

        if (resourceData.isActiveTargetBackBuffer)
            return;

        TextureHandle cameraColor = resourceData.activeColorTexture;

        var desc = cameraData.cameraTargetDescriptor;
        desc.width = m_Width;
        desc.height = m_Height;
        desc.depthBufferBits = 0;
        desc.msaaSamples = 1;

        TextureHandle lowResRT = UniversalRenderer.CreateRenderGraphTexture(
            renderGraph, desc, "_PixelationLowRes", false, FilterMode.Point);

        // Downsample camera color → low-res RT
        using (var builder = renderGraph.AddRasterRenderPass<PassData>("Pixelation Downsample", out var passData))
        {
            passData.source = cameraColor;
            builder.UseTexture(passData.source);
            builder.SetRenderAttachment(lowResRT, 0, AccessFlags.Write);
            builder.SetRenderFunc(static (PassData data, RasterGraphContext ctx) =>
                Blitter.BlitTexture(ctx.cmd, data.source, new Vector4(1, 1, 0, 0), 0, true));
        }

        // Upsample low-res RT → camera color, applying tint material (point sampling = hard chunky pixels)
        using (var builder = renderGraph.AddRasterRenderPass<PassData>("Pixelation Upsample", out var passData))
        {
            passData.source = lowResRT;
            passData.material = m_UpsampleMaterial;
            builder.UseTexture(passData.source);
            builder.SetRenderAttachment(cameraColor, 0, AccessFlags.Write);
            builder.SetRenderFunc(static (PassData data, RasterGraphContext ctx) =>
                Blitter.BlitTexture(ctx.cmd, data.source, new Vector4(1, 1, 0, 0), data.material, 0));
        }
    }
}
