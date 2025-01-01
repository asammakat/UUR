from django.http import JsonResponse
from django.shortcuts import render
from quotes.models import Quote
from quotes.serializers import QuoteSerializer

def homepage(request):
  return render(request, 'homepage.html')

def get_quotes(request):
    quotes = Quote.objects.all()
    serializer = QuoteSerializer(quotes, many=True)
    return JsonResponse({"quotes":serializer.data}, safe=False)

