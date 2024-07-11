from django.http import JsonResponse
from .models import Quote
from .serializers import QuoteSerializer

# Create your views here.
def get_quotes(request):
    quotes = Quote.objects.all()
    serializer = QuoteSerializer(quotes, many=True)
    return JsonResponse({"quotes":serializer.data}, safe=False)
